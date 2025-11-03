import { Capacitor } from "@capacitor/core";
import { registerPlugin } from "@capacitor/core";

/**
 * Peer information from Bluetooth mesh discovery
 * Maps to PeerInfo from Android PeerManager
 */
export interface Peer {
  peerID: string; // Maps to 'id' field
  nickname: string;
  lastSeen: number;
  isDirect: boolean; // Maps to 'isDirectConnection'
  nostrNpub: string; // Placeholder - not in native struct
  isConnected: boolean;
}

/**
 * Ecash message received via Bluetooth
 */
export interface EcashMessage {
  id: string;
  sender: string; // Nostr npub
  senderPeerID: string; // BLE peer ID
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
  peerID?: string; // Optional - null for broadcast
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
    eventName:
      | "ecashReceived"
      | "peerDiscovered"
      | "peerLost"
      | "tokenSent"
      | "tokenSendFailed"
      | "tokenDelivered"
      | "favoriteNotificationReceived"
      | "favoriteRequestReceived"
      | "favoriteAcceptedReceived",
    listenerFunc: (event: any) => void
  ): Promise<{ remove: () => void }>;

  // iOS specific methods
  getActivePeers?(): Promise<{ peers: Peer[] }>;
  openAppSettings?(): Promise<void>;
  startAlwaysOnMode?(): Promise<void>;
  stopAlwaysOnMode?(): Promise<void>;
  isAlwaysOnActive?(): Promise<{ active: boolean }>;
  requestBatteryOptimizationExemption?(): Promise<void>;
}

// Detect if we're running in the native iOS app with WebKit bridge
const isNativeIOS =
  Capacitor.getPlatform() === "ios" &&
  typeof window.webkit?.messageHandlers?.bluetoothBridge !== "undefined";

console.log(
  "🔵 [BluetoothEcash] Platform:",
  Capacitor.getPlatform(),
  "Native iOS:",
  isNativeIOS
);

// Native iOS WebKit bridge implementation
const nativeIOSBridge = {
  startService: async (): Promise<void> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve();
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "startBluetoothService",
        callbackId,
      });
    });
  },

  stopService: async (): Promise<void> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve();
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "stopBluetoothService",
        callbackId,
      });
    });
  },

  sendToken: async (
    options: SendTokenOptions
  ): Promise<{ messageId: string }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "sendToken",
        callbackId,
        options,
      });
    });
  },

  getAvailablePeers: async (): Promise<{ peers: Peer[] }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "getAvailablePeers",
        callbackId,
      });
    });
  },

  getUnclaimedTokens: async (): Promise<{ tokens: EcashMessage[] }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "getUnclaimedTokens",
        callbackId,
      });
    });
  },

  markTokenClaimed: async (options: { messageId: string }): Promise<void> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve();
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "markTokenClaimed",
        callbackId,
        messageId: options.messageId,
      });
    });
  },

  setNickname: async (options: {
    nickname: string;
  }): Promise<{ nickname: string }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "setNickname",
        callbackId,
        nickname: options.nickname,
      });
    });
  },

  getNickname: async (): Promise<{ nickname: string }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "getNickname",
        callbackId,
      });
    });
  },

  isBluetoothEnabled: async (): Promise<{ enabled: boolean }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "isBluetoothEnabled",
        callbackId,
      });
    });
  },

  requestBluetoothEnable: async (): Promise<{
    enabled?: boolean;
    requested?: boolean;
  }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "requestBluetoothEnable",
        callbackId,
      });
    });
  },

  requestPermissions: async (): Promise<{ granted: boolean }> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve(event.detail);
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "requestPermissions",
        callbackId,
      });
    });
  },

  sendTextMessage: async (options: {
    peerID: string;
    message: string;
  }): Promise<void> => {
    return new Promise((resolve, reject) => {
      const callbackId = Math.random().toString(36);

      const handleResponse = (event: CustomEvent) => {
        window.removeEventListener(
          `bluetooth_callback_${callbackId}`,
          handleResponse as EventListener
        );
        resolve();
      };

      window.addEventListener(
        `bluetooth_callback_${callbackId}`,
        handleResponse as EventListener,
        { once: true }
      );

      window.webkit.messageHandlers.bluetoothBridge.postMessage({
        action: "sendTextMessage",
        callbackId,
        peerID: options.peerID,
        message: options.message,
      });
    });
  },

  addListener: async (
    eventName: string,
    listenerFunc: (event: any) => void
  ): Promise<{ remove: () => void }> => {
    // Map event names to native iOS events
    const eventMap: { [key: string]: string } = {
      ecashReceived: "bluetooth_ecashReceived",
      peerDiscovered: "bluetooth_peerDiscovered",
      peerLost: "bluetooth_peerLost",
      tokenSent: "bluetooth_tokenSent",
      tokenSendFailed: "bluetooth_tokenSendFailed",
      tokenDelivered: "bluetooth_tokenDelivered",
      favoriteNotificationReceived: "bluetooth_favoriteNotificationReceived",
      favoriteRequestReceived: "bluetooth_favoriteRequestReceived",
      favoriteAcceptedReceived: "bluetooth_favoriteAcceptedReceived",
    };

    const nativeEventName = eventMap[eventName] || eventName;

    const wrappedListener = (event: CustomEvent) => {
      listenerFunc(event.detail);
    };

    window.addEventListener(nativeEventName, wrappedListener as EventListener);

    return {
      remove: () => {
        window.removeEventListener(
          nativeEventName,
          wrappedListener as EventListener
        );
      },
    };
  },
};

const BluetoothEcash = isNativeIOS
  ? nativeIOSBridge
  : registerPlugin<BluetoothEcashPlugin>("BluetoothEcash", {
      web: () => ({
        // Web implementation (stub - Bluetooth not available in browser)
        startService: async () => {
          console.warn("Bluetooth mesh not available in web browser");
        },
        stopService: async () => {},
        setNickname: async () => ({ nickname: "" }),
        getNickname: async () => ({ nickname: "" }),
        isBluetoothEnabled: async () => ({ enabled: false }),
        requestBluetoothEnable: async () => ({ requested: false }),
        sendToken: async () => ({ messageId: "" }),
        sendTextMessage: async () => {},
        getAvailablePeers: async () => ({ peers: [] }),
        getUnclaimedTokens: async () => ({ tokens: [] }),
        markTokenClaimed: async () => {},
        requestPermissions: async () => ({ granted: false }),
        addListener: async () => ({ remove: () => {} }),
      }),
    });

console.log("🔵 [BluetoothEcash] Plugin registered successfully");

export default BluetoothEcash;
