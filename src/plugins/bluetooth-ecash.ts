import { registerPlugin } from "@capacitor/core";

/**
 * Peer information from Bluetooth mesh discovery.
 */
export interface Peer {
  peerID: string;
  nickname: string;
  lastSeen: number;
  isDirect: boolean;
  nostrNpub: string;
  isConnected: boolean;
}

/**
 * Ecash message received via Bluetooth.
 */
export interface EcashMessage {
  id: string;
  sender: string;
  senderPeerID: string;
  timestamp: number;
  amount: number;
  unit: string;
  cashuToken: string;
  mint: string;
  memo: string;
  claimed: boolean;
  deliveryStatus: string;
}

export interface SendTokenOptions {
  token: string;
  amount: number;
  unit: string;
  mint: string;
  peerID?: string;
  memo?: string;
  senderNpub: string;
}

export interface BluetoothEcashPlugin {
  isBluetoothEnabled(): Promise<{ enabled: boolean }>;
  requestBluetoothEnable(): Promise<{ enabled?: boolean; requested?: boolean }>;
  startService(): Promise<void>;
  stopService(): Promise<void>;
  setNickname(options: { nickname: string }): Promise<{ nickname: string }>;
  getNickname(): Promise<{ nickname: string }>;
  sendToken(options: SendTokenOptions): Promise<{ messageId: string }>;
  sendTextMessage(options: { peerID: string; message: string }): Promise<void>;
  getAvailablePeers(): Promise<{ peers: Peer[] }>;
  getUnclaimedTokens(): Promise<{ tokens: EcashMessage[] }>;
  markTokenClaimed(options: { messageId: string }): Promise<void>;
  requestPermissions(): Promise<{ granted: boolean }>;
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
    listenerFunc: (data: any) => void
  ): Promise<{ remove: () => void }>;
}

/**
 * Register Capacitor plugin.
 * Native implementation is used on iOS; web stub avoids UNIMPLEMENTED errors.
 */
const BluetoothEcash = registerPlugin<BluetoothEcashPlugin>("BluetoothEcash", {
  web: () => ({
    async isBluetoothEnabled() {
      return { enabled: false };
    },
    async requestBluetoothEnable() {
      return { requested: false };
    },
    async startService() {
      console.warn("[BluetoothEcash] startService is not available on web.");
    },
    async stopService() {
      console.warn("[BluetoothEcash] stopService is not available on web.");
    },
    async setNickname(options: { nickname: string }) {
      return { nickname: options.nickname };
    },
    async getNickname() {
      return { nickname: "" };
    },
    async sendToken() {
      return { messageId: "" };
    },
    async sendTextMessage() {
      /* no-op */
    },
    async getAvailablePeers() {
      return { peers: [] };
    },
    async getUnclaimedTokens() {
      return { tokens: [] };
    },
    async markTokenClaimed() {
      /* no-op */
    },
    async requestPermissions() {
      return { granted: false };
    },
    async addListener() {
      return { remove: () => {} };
    },
  }),
});

export default BluetoothEcash;
