import { registerPlugin } from '@capacitor/core';

/**
 * Peer information from Bluetooth mesh discovery
 * Maps to PeerInfo from Android PeerManager
 */
export interface Peer {
  peerID: string;  // Maps to 'id' field
  nickname: string;
  lastSeen: number;
  isDirect: boolean;  // Maps to 'isDirectConnection'
  nostrNpub: string;  // Placeholder - not in native struct
  isConnected: boolean;
}

/**
 * Ecash message received via Bluetooth
 */
export interface EcashMessage {
  id: string;
  sender: string;  // Nostr npub
  senderPeerID: string;  // BLE peer ID
  timestamp: number;
  amount: number;
  unit: string;
  cashuToken: string;
  mint: string;
  memo: string;
  claimed: boolean;
  deliveryStatus: string;
}

/**
 * Options for sending ecash token
 */
export interface SendTokenOptions {
  token: string;
  amount: number;
  unit: string;
  mint: string;
  peerID?: string;  // Optional - null for broadcast
  memo?: string;
  senderNpub: string;
}

/**
 * Bluetooth Ecash Plugin Interface
 *
 * Provides methods to send/receive ecash tokens over Bluetooth mesh network
 */
export interface BluetoothEcashPlugin {
  /**
   * Check if Bluetooth is enabled on the device
   */
  isBluetoothEnabled(): Promise<{ enabled: boolean }>;

  /**
   * Prompt user to enable Bluetooth (shows system dialog)
   */
  requestBluetoothEnable(): Promise<{ enabled?: boolean; requested?: boolean }>;

  /**
   * Start the Bluetooth mesh service
   * Begins advertising and scanning for nearby peers
   */
  startService(): Promise<void>;

  /**
   * Stop the Bluetooth mesh service
   */
  stopService(): Promise<void>;

  /**
   * Set the Bluetooth nickname (how you appear to nearby peers)
   * Requires service restart to take effect
   *
   * @param options Object containing nickname string (3-32 characters)
   */
  setNickname(options: { nickname: string }): Promise<{ nickname: string }>;

  /**
   * Get the current Bluetooth nickname
   */
  getNickname(): Promise<{ nickname: string }>;

  /**
   * Send ecash token to nearby peer(s)
   *
   * @param options Token details and optional target peer
   * @returns Message ID for tracking delivery
   */
  sendToken(options: SendTokenOptions): Promise<{ messageId: string }>;

  /**
   * Send plain text message to a specific peer
   * Used for favorite notifications and system messages
   *
   * @param options Peer ID and message content
   */
  sendTextMessage(options: { peerID: string; message: string }): Promise<void>;

  /**
   * Get list of currently available peers
   *
   * @returns Array of nearby peers
   */
  getAvailablePeers(): Promise<{ peers: Peer[] }>;

  /**
   * Get unclaimed tokens received via Bluetooth
   *
   * @returns Array of unclaimed ecash messages
   */
  getUnclaimedTokens(): Promise<{ tokens: EcashMessage[] }>;

  /**
   * Mark a token as claimed after redemption
   *
   * @param options Message ID of the token
   */
  markTokenClaimed(options: { messageId: string }): Promise<void>;

  /**
   * Request required Bluetooth permissions
   *
   * @returns Permission grant status
   */
  requestPermissions(): Promise<{ granted: boolean }>;

  /**
   * Add event listeners for Bluetooth events
   */
  addListener(
    eventName: 'ecashReceived' | 'peerDiscovered' | 'peerLost' | 'tokenSent' | 'tokenSendFailed' | 'tokenDelivered' | 'favoriteNotificationReceived' | 'favoriteRequestReceived' | 'favoriteAcceptedReceived',
    listenerFunc: (event: any) => void
  ): Promise<{ remove: () => void }>;
}

const BluetoothEcash = registerPlugin<BluetoothEcashPlugin>('BluetoothEcash', {
  web: () => ({
    // Web implementation (stub - Bluetooth not available in browser)
    startService: async () => {
      console.warn('Bluetooth mesh not available in web browser');
    },
    stopService: async () => {},
    setNickname: async () => ({ nickname: '' }),
    getNickname: async () => ({ nickname: '' }),
    isBluetoothEnabled: async () => ({ enabled: false }),
    requestBluetoothEnable: async () => ({ requested: false }),
    sendToken: async () => ({ messageId: '' }),
    sendTextMessage: async () => {},
    getAvailablePeers: async () => ({ peers: [] }),
    getUnclaimedTokens: async () => ({ tokens: [] }),
    markTokenClaimed: async () => {},
    requestPermissions: async () => ({ granted: false }),
    addListener: async () => ({ remove: () => {} }),
  }),
});

export default BluetoothEcash;

