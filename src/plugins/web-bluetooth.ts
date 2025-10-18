/**
 * Web Bluetooth API wrapper for desktop PWA support
 * Enables Bluetooth mesh on Chrome/Edge desktop browsers
 */

const SERVICE_UUID = 'f47b5e2d-4a9e-4c5a-9b3f-8e1d2c3a4b5c';
const CHARACTERISTIC_UUID = 'a1b2c3d4-e5f6-4a5b-8c9d-0e1f2a3b4c5d';

export interface WebBluetoothPeer {
  id: string;
  nickname: string;
  device: BluetoothDevice;
  server?: BluetoothRemoteGATTServer;
  characteristic?: BluetoothRemoteGATTCharacteristic;
  lastSeen: number;
}

export class WebBluetoothService {
  private devices: Map<string, WebBluetoothPeer> = new Map();
  private myNickname = 'Bitpoints User';
  private isScanning = false;
  private onTokenReceived?: (token: string, sender: WebBluetoothPeer) => void;
  private onPeerDiscovered?: (peer: WebBluetoothPeer) => void;

  /**
   * Check if Web Bluetooth is available
   */
  static isAvailable(): boolean {
    return typeof navigator !== 'undefined' && 
           'bluetooth' in navigator;
  }

  /**
   * Initialize with nickname
   */
  initialize(nickname: string) {
    this.myNickname = nickname;
  }

  /**
   * Request and connect to a Bluetooth device
   */
  async requestDevice(): Promise<WebBluetoothPeer | null> {
    try {
      console.log('🔍 Starting Web Bluetooth device discovery...');
      console.log('📍 Current URL:', window.location.href);
      console.log('🔒 HTTPS:', window.location.protocol === 'https:');
      
      // Check if Web Bluetooth is available
      if (!navigator.bluetooth) {
        throw new Error('Web Bluetooth not supported in this browser');
      }
      
      // First try to find devices with our specific service
      let device;
      try {
        console.log('🎯 Attempting to find devices with Bitpoints service...');
        device = await navigator.bluetooth.requestDevice({
          filters: [{ services: [SERVICE_UUID] }],
          optionalServices: [SERVICE_UUID]
        });
        console.log('✅ Found device with Bitpoints service:', device.name);
      } catch (serviceError) {
        console.log('⚠️ No devices with Bitpoints service found, trying generic BLE devices...');
        console.log('Service error:', serviceError);
        
        // Fallback: Look for any BLE device (more compatible)
        console.log('🔍 Requesting all BLE devices...');
        device = await navigator.bluetooth.requestDevice({
          acceptAllDevices: true,
          optionalServices: [SERVICE_UUID]
        });
        console.log('✅ Found generic BLE device:', device.name);
      }

      // Extract nickname from device name
      let nickname = device.name || 'Unknown Device';
      if (device.name && device.name.startsWith('BP:')) {
        nickname = device.name.substring(3);
      } else if (device.name) {
        // Use device name as nickname
        nickname = device.name;
      }

      const peer: WebBluetoothPeer = {
        id: device.id,
        nickname,
        device,
        lastSeen: Date.now()
      };

      this.devices.set(device.id, peer);
      
      // Try to connect to device (may fail if it doesn't support our service)
      try {
        await this.connectToPeer(peer);
      } catch (connectError) {
        console.warn('Could not connect to device with Bitpoints service, but device is available:', connectError);
        // Still return the peer even if we can't connect to the specific service
      }

      if (this.onPeerDiscovered) {
        this.onPeerDiscovered(peer);
      }

      return peer;
    } catch (error) {
      console.error('Failed to request Bluetooth device:', error);
      
      // Check if it's a user cancellation
      if (error.name === 'NotFoundError' || error.name === 'SecurityError') {
        console.log('User cancelled device selection or permission denied');
      }
      
      return null;
    }
  }

  /**
   * Connect to a peer and set up token receiving
   */
  private async connectToPeer(peer: WebBluetoothPeer): Promise<void> {
    try {
      if (!peer.device.gatt) {
        console.error('Device has no GATT server');
        return;
      }

      // Connect to GATT server
      const server = await peer.device.gatt.connect();
      peer.server = server;

      // Get service
      const service = await server.getPrimaryService(SERVICE_UUID);

      // Get characteristic
      const characteristic = await service.getCharacteristic(CHARACTERISTIC_UUID);
      peer.characteristic = characteristic;

      // Set up notifications for incoming tokens
      characteristic.addEventListener('characteristicvaluechanged', (event: Event) => {
        const target = event.target as BluetoothRemoteGATTCharacteristic;
        const value = target.value;
        if (value) {
          this.handleReceivedData(value, peer);
        }
      });

      await characteristic.startNotifications();

      console.log(`Connected to peer: ${peer.nickname} (${peer.id})`);
    } catch (error) {
      console.error('Failed to connect to peer:', error);
    }
  }

  /**
   * Send token to a specific peer
   */
  async sendToken(token: string, peerId: string): Promise<boolean> {
    const peer = this.devices.get(peerId);
    if (!peer || !peer.characteristic) {
      console.error('Peer not connected:', peerId);
      return false;
    }

    try {
      // Create token message
      const message = {
        type: 'ECASH_TOKEN',
        token,
        sender: this.myNickname,
        timestamp: Date.now()
      };

      const data = new TextEncoder().encode(JSON.stringify(message));
      
      // Write to characteristic
      await peer.characteristic.writeValue(data);
      
      console.log(`Sent token to ${peer.nickname} via Web Bluetooth`);
      return true;
    } catch (error) {
      console.error('Failed to send token:', error);
      return false;
    }
  }

  /**
   * Handle received data from characteristic
   */
  private handleReceivedData(value: DataView, sender: WebBluetoothPeer) {
    try {
      const decoder = new TextDecoder();
      const text = decoder.decode(value);
      const message = JSON.parse(text);

      if (message.type === 'ECASH_TOKEN' && message.token) {
        console.log(`Received token from ${sender.nickname} via Web Bluetooth`);
        
        if (this.onTokenReceived) {
          this.onTokenReceived(message.token, sender);
        }
      }
    } catch (error) {
      console.error('Failed to parse received data:', error);
    }
  }

  /**
   * Get list of connected peers
   */
  getPeers(): WebBluetoothPeer[] {
    return Array.from(this.devices.values());
  }

  /**
   * Disconnect from a peer
   */
  async disconnect(peerId: string) {
    const peer = this.devices.get(peerId);
    if (peer && peer.server) {
      peer.server.disconnect();
      this.devices.delete(peerId);
    }
  }

  /**
   * Disconnect from all peers
   */
  disconnectAll() {
    for (const peer of this.devices.values()) {
      if (peer.server) {
        peer.server.disconnect();
      }
    }
    this.devices.clear();
  }

  /**
   * Set callback for token received
   */
  setOnTokenReceived(callback: (token: string, sender: WebBluetoothPeer) => void) {
    this.onTokenReceived = callback;
  }

  /**
   * Set callback for peer discovered
   */
  setOnPeerDiscovered(callback: (peer: WebBluetoothPeer) => void) {
    this.onPeerDiscovered = callback;
  }
}

export const webBluetoothService = new WebBluetoothService();

