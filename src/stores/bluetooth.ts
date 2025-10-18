import { defineStore } from 'pinia';
import BluetoothEcash, { Peer, EcashMessage, SendTokenOptions } from 'src/plugins/bluetooth-ecash';
import { webBluetoothService, WebBluetoothService } from 'src/plugins/web-bluetooth';
import { useWalletStore } from './wallet';
import { useNostrStore } from './nostr';
import { useReceiveTokensStore } from './receiveTokensStore';
import { useFavoritesStore } from './favorites';
import { useLocalStorage } from '@vueuse/core';
import { notifySuccess, notifyError, notifyWarning } from 'src/js/notify';
import { Capacitor } from '@capacitor/core';

/**
 * Bluetooth Mesh Ecash Store
 *
 * Manages Bluetooth mesh networking for offline ecash token transfers
 */
export const useBluetoothStore = defineStore('bluetooth', {
  state: () => ({
    isActive: false,
    isInitialized: false,
    nearbyPeers: [] as Peer[],
    unclaimedTokens: useLocalStorage<EcashMessage[]>('bluetooth-unclaimed-tokens', []),
    contacts: useLocalStorage<BluetoothContact[]>('bluetooth-contacts', []),
    pendingMessages: [] as string[],  // Message IDs being sent
    nickname: useLocalStorage<string>('bluetooth-nickname', 'Bitpoints User'),
    alwaysOnEnabled: useLocalStorage<boolean>('bluetooth-always-on', true),
    alwaysOnActive: false,
  }),

  getters: {
    /**
     * Check if running on desktop (PWA) vs mobile (native app)
     */
    isDesktop: () => {
      return !Capacitor.isNativePlatform();
    },

    /**
     * Check if Web Bluetooth API is available (desktop Chrome/Edge)
     */
    isWebBluetoothAvailable: () => {
      try {
        return WebBluetoothService.isAvailable();
      } catch (error) {
        console.error('Error checking Web Bluetooth availability:', error);
        return false;
      }
    },

    /**
     * Check if any Bluetooth is available (native or web)
     */
    isBluetoothAvailable(): boolean {
      return Capacitor.isNativePlatform() || this.isWebBluetoothAvailable;
    },

    /**
     * Get peers sorted by last seen (most recent first)
     */
    sortedPeers: (state) => {
      return [...state.nearbyPeers].sort((a, b) => b.lastSeen - a.lastSeen);
    },

    /**
     * Get only directly connected peers (not via relay)
     */
    directPeers: (state) => {
      return state.nearbyPeers.filter(p => p.isDirect);
    },

    /**
     * Get peers with known Nostr identities
     */
    knownPeers: (state) => {
      return state.nearbyPeers.filter(p => p.nostrNpub && p.nostrNpub.length > 0);
    },

    /**
     * Get count of unclaimed tokens
     */
    unclaimedCount: (state) => {
      return state.unclaimedTokens.filter(t => !t.claimed).length;
    },

    /**
     * Total value of unclaimed tokens (in sats)
     */
    unclaimedValue: (state) => {
      return state.unclaimedTokens
        .filter(t => !t.claimed && t.unit === 'sat')
        .reduce((sum, t) => sum + t.amount, 0);
    },
  },

  actions: {
    /**
     * Initialize the Bluetooth service and event listeners
     */
    async initialize() {
      if (this.isInitialized) return;

      try {
        // Desktop PWA with Web Bluetooth
        if (this.isDesktop) {
          if (!this.isWebBluetoothAvailable) {
            console.log('Web Bluetooth not available. Use Chrome or Edge browser.');
            return;
          }

          // Set up Web Bluetooth callbacks
          webBluetoothService.initialize(this.nickname);

          webBluetoothService.setOnPeerDiscovered((peer) => {
            console.log('Web Bluetooth: Peer discovered', peer);
            this.handlePeerDiscovered({
              peerID: peer.id,
              nickname: peer.nickname,
              lastSeen: peer.lastSeen,
              isDirect: true,
              nostrNpub: '',
              isConnected: true,
            });
          });

          webBluetoothService.setOnTokenReceived((token, sender) => {
            console.log('Web Bluetooth: Token received', token);
            // Handle received token
            this.handleEcashReceived({
              id: Date.now().toString(),
              sender: sender.nickname,
              senderPeerID: sender.id,
              timestamp: Date.now(),
              amount: 0, // Parse from token
              unit: 'sat',
              cashuToken: token,
              mint: '',
              memo: '',
              claimed: false,
              deliveryStatus: 'delivered',
            });
          });

          this.isInitialized = true;
          console.log('Web Bluetooth service initialized');
          return;
        }

        // Native mobile app
        // Set up event listeners for native plugin
        await BluetoothEcash.addListener('ecashReceived', (event: EcashMessage) => {
          console.log('Ecash received via Bluetooth:', event);
          this.handleEcashReceived(event);
        });

        await BluetoothEcash.addListener('peerDiscovered', (event: { peerID: string; nickname: string; lastSeen: number; isDirect: boolean; nostrNpub: string }) => {
          console.log('Peer discovered:', event);
          this.handlePeerDiscovered(event as Peer);
        });

        await BluetoothEcash.addListener('peerLost', (event: { peerID: string }) => {
          console.log('Peer lost:', event);
          this.handlePeerLost(event.peerID);
        });

        await BluetoothEcash.addListener('tokenSent', (event: { messageId: string }) => {
          console.log('Token sent:', event);
          this.handleTokenSent(event.messageId);
        });

        await BluetoothEcash.addListener('tokenDelivered', (event: { messageId: string; peerID: string }) => {
          console.log('Token delivered:', event);
          this.handleTokenDelivered(event.messageId, event.peerID);
        });

        await BluetoothEcash.addListener('favoriteNotificationReceived', (event: { peerID: string; npub: string; isFavorite: boolean }) => {
          console.log('⭐️ Favorite notification received:', event);
          this.handleFavoriteNotification(event.peerID, event.npub, event.isFavorite);
        });

        await BluetoothEcash.addListener('favoriteRequestReceived', (event: { peerID: string; nickname: string; npub: string }) => {
          console.log('📬 [LISTENER] Favorite request received:', event);
          console.log('📬 [LISTENER] peerID:', event.peerID);
          console.log('📬 [LISTENER] nickname:', event.nickname);
          console.log('📬 [LISTENER] npub:', event.npub?.substring(0, 16));
          this.handleFavoriteRequest(event.peerID, event.nickname, event.npub);
        });

        await BluetoothEcash.addListener('favoriteAcceptedReceived', (event: { peerID: string; npub: string }) => {
          console.log('✅ Favorite accepted received:', event);
          this.handleFavoriteAccepted(event.peerID, event.npub);
        });

        this.isInitialized = true;
        console.log('Bluetooth ecash service initialized');
      } catch (e) {
        console.error('Failed to initialize Bluetooth service:', e);
      }
    },

    /**
     * Start Bluetooth mesh service
     */
    async startService() {
      try {
        // Desktop PWA with Web Bluetooth
        if (this.isDesktop) {
          console.log('🖥️ Desktop PWA detected, using Web Bluetooth...');

          if (!this.isWebBluetoothAvailable) {
            console.error('❌ Web Bluetooth not available');
            notifyError('Web Bluetooth not supported. Please use Chrome or Edge browser.');
            return false;
          }

          console.log('✅ Web Bluetooth available, starting service...');
          console.log('🔗 Current URL:', window.location.href);
          console.log('🔒 HTTPS enabled:', window.location.protocol === 'https:');

          // Web Bluetooth requires user interaction to request device
          // This will show browser's device picker dialog
          console.log('🎯 Requesting Bluetooth device...');
          const peer = await webBluetoothService.requestDevice();

          if (!peer) {
            // Don't show error for user cancellation
            console.log('⚠️ User cancelled device selection or no device available');
            return false;
          }

          console.log('🎉 Device connected successfully:', peer);
          this.isActive = true;
          notifySuccess(`Connected to ${peer.nickname}!`);
          console.log('✅ Web Bluetooth service started');
          return true;
        }

        // Native mobile app
        // Request permissions first
        const { granted } = await BluetoothEcash.requestPermissions();
        if (!granted) {
          notifyWarning('Bluetooth permissions required for nearby payments');
          return false;
        }

        // Set nickname in native plugin before starting
        console.log(`Setting Bluetooth nickname: ${this.nickname}`);
        await BluetoothEcash.setNickname({ nickname: this.nickname });

        await BluetoothEcash.startService();
        this.isActive = true;
        console.log(`Bluetooth mesh service started with nickname: ${this.nickname}`);

        // Start polling for peers
        this.startPeerPolling();

        return true;
      } catch (e) {
        console.error('Failed to start Bluetooth service:', e);
        notifyError('Failed to start Bluetooth service');
        return false;
      }
    },

    /**
     * Stop Bluetooth mesh service
     */
    async stopService() {
      try {
        if (this.isDesktop) {
          webBluetoothService.disconnectAll();
          this.isActive = false;
          this.nearbyPeers = [];
          console.log('Web Bluetooth service stopped');
          return;
        }

        await BluetoothEcash.stopService();
        this.isActive = false;
        this.nearbyPeers = [];
        console.log('Bluetooth mesh service stopped');
      } catch (e) {
        console.error('Failed to stop Bluetooth service:', e);
      }
    },

    /**
     * Update Bluetooth nickname
     * Restarts service if active to apply new nickname
     */
    async updateNickname(newNickname: string) {
      if (newNickname.length < 3 || newNickname.length > 32) {
        throw new Error('Nickname must be 3-32 characters');
      }

      const wasActive = this.isActive;
      this.nickname = newNickname;

      // Update in native plugin (mobile) or web bluetooth service (desktop)
      if (!this.isDesktop) {
        await BluetoothEcash.setNickname({ nickname: newNickname });
      } else {
        webBluetoothService.initialize(newNickname);
      }

      // Restart service to apply new nickname in announcements
      if (wasActive) {
        await this.stopService();
        await this.startService();
        console.log(`Bluetooth nickname updated to: ${newNickname}`);
      }
    },

    /**
     * Send ecash token to nearby peer(s)
     */
    async sendToken(options: SendTokenOptions): Promise<string | null> {
      console.log('🔵 [STORE] sendToken called with:', options);

      try {
        // Desktop PWA with Web Bluetooth
        if (this.isDesktop) {
          if (!options.peerID) {
            notifyError('Web Bluetooth requires specific peer selection');
            return null;
          }

          console.log('🔵 [WEB] Sending token via Web Bluetooth...');
          const success = await webBluetoothService.sendToken(options.token, options.peerID);

          if (success) {
            const messageId = Date.now().toString();
            this.pendingMessages.push(messageId);
            console.log('🔵 [WEB] Success, messageId:', messageId);
            return messageId;
          } else {
            notifyError('Failed to send token via Web Bluetooth');
            return null;
          }
        }

        // Native mobile app
        console.log('🔵 [STORE] Calling BluetoothEcash.sendToken...');
        const result = await BluetoothEcash.sendToken(options);
        console.log('🔵 [STORE] Native returned:', result);

        const { messageId } = result;
        this.pendingMessages.push(messageId);
        console.log('🔵 [STORE] Success, returning messageId:', messageId);
        return messageId;
      } catch (e) {
        console.error('🔵 [STORE ERROR]:', e);
        notifyError('Failed to send token via Bluetooth');
        return null;
      }
    },

    /**
     * Send plain text message to a specific peer (for favorite notifications, etc)
     */
    async sendTextMessage(peerID: string, message: string): Promise<boolean> {
      try {
        if (!this.isActive) {
          console.warn('Bluetooth not active, cannot send text message');
          return false;
        }

        if (this.isDesktop) {
          // Web Bluetooth text messaging not implemented yet
          console.warn('Web Bluetooth text messaging not supported yet');
          return false;
        }

        // Native: Use the plugin's sendTextMessage method if available, or fall back to using mesh service directly
        // For now, we'll use the native mesh service's sendMessageToPeer
        await BluetoothEcash.sendTextMessage({ peerID, message });
        console.log(`📤 Sent text message to ${peerID}: ${message.substring(0, 30)}...`);
        return true;
      } catch (e) {
        console.error('Failed to send text message:', e);
        return false;
      }
    },

    /**
     * Claim a received token
     */
    async claimToken(messageId: string) {
      try {
        const message = this.unclaimedTokens.find(t => t.id === messageId);
        if (!message) {
          throw new Error('Token not found');
        }

        // Use wallet store to receive the token
        const walletStore = useWalletStore();
        const receiveStore = useReceiveTokensStore();

        receiveStore.receiveData.tokensBase64 = message.cashuToken;
        const success = await receiveStore.receiveIfDecodes();

        if (success) {
          // Mark as claimed
          await BluetoothEcash.markTokenClaimed({ messageId });

          const index = this.unclaimedTokens.findIndex(t => t.id === messageId);
          if (index !== -1) {
            this.unclaimedTokens[index] = { ...message, claimed: true };
          }

          // Add sender to contacts
          this.addContact(message.sender, message.senderPeerID);

          notifySuccess(`Claimed ${message.amount} ${message.unit} from ${message.sender.substring(0, 16)}...`);
          return true;
        } else {
          throw new Error('Failed to redeem token with mint');
        }
      } catch (e) {
        console.error('Failed to claim token:', e);
        notifyError('Failed to claim token');
        return false;
      }
    },

    /**
     * Auto-claim all unclaimed tokens (when online)
     */
    async autoClaimTokens() {
      if (!navigator.onLine) {
        console.log('Offline - skipping auto-claim');
        return;
      }

      const unclaimed = this.unclaimedTokens.filter(t => !t.claimed);
      console.log(`Auto-claiming ${unclaimed.length} tokens`);

      for (const token of unclaimed) {
        await this.claimToken(token.id);
        // Small delay between claims
        await new Promise(resolve => setTimeout(resolve, 500));
      }
    },

    /**
     * Handle ecash received event
     */
    handleEcashReceived(message: EcashMessage) {
      // Add to unclaimed tokens
      const existing = this.unclaimedTokens.find(t => t.id === message.id);
      if (!existing) {
        this.unclaimedTokens.push(message);

        // Show notification
        notifySuccess(`Received ${message.amount} ${message.unit} via Bluetooth!`, message.memo || 'From nearby peer');

        // Try to auto-claim if online
        if (navigator.onLine) {
          this.claimToken(message.id);
        }
      }
    },

    /**
     * Handle peer discovered event
     */
    handlePeerDiscovered(peer: Peer) {
      const existing = this.nearbyPeers.find(p => p.peerID === peer.peerID);
      if (!existing) {
        this.nearbyPeers.push(peer);
        console.log(`New peer discovered: ${peer.peerID} (${peer.nickname || 'unnamed'})`);
      } else {
        // Update existing peer info
        const index = this.nearbyPeers.findIndex(p => p.peerID === peer.peerID);
        this.nearbyPeers[index] = peer;
      }
    },

    /**
     * Handle peer lost event
     */
    handlePeerLost(peerID: string) {
      const index = this.nearbyPeers.findIndex(p => p.peerID === peerID);
      if (index !== -1) {
        this.nearbyPeers.splice(index, 1);
        console.log(`Peer lost: ${peerID}`);
      }
    },

    /**
     * Handle token sent event
     */
    handleTokenSent(messageId: string) {
      const index = this.pendingMessages.indexOf(messageId);
      if (index !== -1) {
        this.pendingMessages.splice(index, 1);
      }
    },

    /**
     * Handle token delivered event
     */
    handleTokenDelivered(messageId: string, peerID: string) {
      console.log(`Token ${messageId} delivered to ${peerID}`);
      // Could update UI to show delivery confirmation
    },

    /**
     * Handle favorite notification received (matches bitchat implementation)
     */
    handleFavoriteNotification(peerID: string, npub: string, isFavorite: boolean) {
      console.log(`⭐️ ${isFavorite ? 'FAVORITED' : 'UNFAVORITED'} by ${peerID} with npub: ${npub.substring(0, 16)}...`);

      // Update favorites store with the peer's Nostr npub
      const favoritesStore = useFavoritesStore();
      favoritesStore.updateNostrNpub(peerID, npub);

      // If they favorited us, update the theyFavoritedUs flag
      if (isFavorite) {
        favoritesStore.updatePeerFavoritedUs(peerID, true);
      } else {
        favoritesStore.updatePeerFavoritedUs(peerID, false);
      }

      // Show notification to user
      const peer = this.nearbyPeers.find(p => p.peerID === peerID);
      const nickname = peer?.nickname || peerID.substring(0, 8);

      if (isFavorite) {
        const isMutual = favoritesStore.isMutualFavorite(peerID);
        if (isMutual) {
          notifySuccess(`💕 Mutual favorite with ${nickname}! You can now message via Nostr.`);
        } else {
          notifySuccess(`⭐️ ${nickname} added you as favorite. Favorite back for Nostr messaging!`);
        }
      }
    },

    handleFavoriteRequest(peerID: string, nickname: string, npub: string) {
      console.log('📬 [HANDLER] handleFavoriteRequest called');
      console.log(`📬 Favorite request from ${nickname} (${peerID}) with npub: ${npub.substring(0, 16)}...`);

      // Add to pending requests
      const favoritesStore = useFavoritesStore();
      console.log('📬 [HANDLER] Adding pending request to store...');
      favoritesStore.addPendingRequest(peerID, nickname, npub);
      console.log('📬 [HANDLER] Pending request added. Count:', favoritesStore.pendingCount);

      // Show notification with action
      console.log('📬 [HANDLER] Showing notification...');
      notifySuccess(`📬 ${nickname} wants to be your favorite!`, {
        timeout: 5000,
        actions: [
          {
            label: 'View',
            color: 'white',
            handler: () => {
              console.log('📬 [NOTIFICATION] View action clicked');
            }
          }
        ]
      });
    },

    handleFavoriteAccepted(peerID: string, npub: string) {
      console.log(`✅ Favorite accepted by ${peerID} with npub: ${npub.substring(0, 16)}...`);

      // Update favorites store with the peer's Nostr npub
      const favoritesStore = useFavoritesStore();

      // Ensure favorite exists before updating npub
      if (!favoritesStore.favorites[peerID]) {
        const peer = this.nearbyPeers.find(p => p.peerID === peerID);
        console.log(`✅ Creating favorite for ${peerID} before updating npub`);
        favoritesStore.addFavorite(peerID, peer?.nickname || 'Unknown', npub);
      } else {
        console.log(`✅ Updating existing favorite npub for ${peerID}`);
        favoritesStore.updateNostrNpub(peerID, npub);
      }

      favoritesStore.updatePeerFavoritedUs(peerID, true);

      // Show success notification
      const peer = this.nearbyPeers.find(p => p.peerID === peerID);
      const nickname = peer?.nickname || peerID.substring(0, 8);
      notifySuccess(`💕 ${nickname} accepted your favorite request! You can now message via Nostr.`);
    },

    /**
     * Poll for available peers periodically
     */
    async startPeerPolling() {
      if (!this.isActive) return;

      const poll = async () => {
        if (!this.isActive) return;

        try {
          const { peers } = await BluetoothEcash.getAvailablePeers();

          // Update peer list
          this.nearbyPeers = peers;

          // Poll again in 5 seconds
          setTimeout(poll, 5000);
        } catch (e) {
          console.error('Failed to poll peers:', e);
          setTimeout(poll, 10000);  // Retry slower on error
        }
      };

      poll();
    },

    /**
     * Add a contact after ecash exchange
     */
    addContact(npub: string, peerID: string) {
      const existing = this.contacts.find(c => c.npub === npub);
      if (!existing) {
        this.contacts.push({
          npub,
          peerID,
          addedAt: Date.now(),
          lastInteraction: Date.now(),
          nickname: '',
        });
        console.log(`Added contact: ${npub}`);

        // Sync to Nostr when online
        if (navigator.onLine) {
          this.syncContactsToNostr();
        }
      } else {
        // Update last interaction time
        const index = this.contacts.findIndex(c => c.npub === npub);
        this.contacts[index].lastInteraction = Date.now();
      }
    },

    /**
     * Sync contacts to Nostr contact list (NIP-02)
     */
    async syncContactsToNostr() {
      try {
        const nostrStore = useNostrStore();
        // Note: NIP-02 contact list publishing will be implemented in future version
        // For now, contacts are stored locally and synced via favorites system
        console.log('Contacts sync to Nostr planned for future release', this.contacts.length, 'contacts');
      } catch (e) {
        console.error('Failed to sync contacts to Nostr:', e);
      }
    },

    /**
     * Start always-on mode (Android only)
     */
    async startAlwaysOnMode() {
      if (!Capacitor.isNativePlatform()) {
        notifyWarning('Always-on mode is only available on Android devices');
        return;
      }

      try {
        const result = await BluetoothEcash.startAlwaysOnMode();

        if (result.success) {
          this.alwaysOnActive = true;
          notifySuccess('Always-on mode started. Bluetooth mesh will stay active 24/7.');
          console.log('Always-on mode started:', result.message);
        } else {
          notifyError('Failed to start always-on mode');
        }
      } catch (error) {
        console.error('Error starting always-on mode:', error);
        notifyError(`Failed to start always-on mode: ${error.message}`);
      }
    },

    /**
     * Stop always-on mode (Android only)
     */
    async stopAlwaysOnMode() {
      if (!Capacitor.isNativePlatform()) {
        notifyWarning('Always-on mode is only available on Android devices');
        return;
      }

      try {
        const result = await BluetoothEcash.stopAlwaysOnMode();

        if (result.success) {
          this.alwaysOnActive = false;
          this.alwaysOnEnabled = false;
          notifySuccess('Always-on mode stopped');
          console.log('Always-on mode stopped:', result.message);
        } else {
          notifyError('Failed to stop always-on mode');
        }
      } catch (error) {
        console.error('Error stopping always-on mode:', error);
        notifyError(`Failed to stop always-on mode: ${error.message}`);
      }
    },

    /**
     * Check if always-on mode is active
     */
    async checkAlwaysOnStatus() {
      if (!Capacitor.isNativePlatform()) {
        this.alwaysOnActive = false;
        return;
      }

      try {
        const result = await BluetoothEcash.isAlwaysOnActive();
        this.alwaysOnActive = result.isActive;
        console.log('Always-on status checked:', this.alwaysOnActive);
      } catch (error) {
        console.error('Error checking always-on status:', error);
        this.alwaysOnActive = false;
      }
    },

    /**
     * Toggle always-on mode
     */
    async toggleAlwaysOnMode(enabled: boolean) {
      this.alwaysOnEnabled = enabled;

      if (enabled) {
        await this.startAlwaysOnMode();
      } else {
        await this.stopAlwaysOnMode();
      }
    },

    /**
     * Request battery optimization exemption
     */
    async requestBatteryOptimizationExemption() {
      if (!Capacitor.isNativePlatform()) {
        notifyWarning('Battery optimization settings are only available on Android devices');
        return;
      }

      try {
        const result = await BluetoothEcash.requestBatteryOptimizationExemption();

        if (result.success) {
          notifySuccess('Battery optimization dialog opened. Please allow Bitpoints to run in background.');
          console.log('Battery optimization exemption requested:', result.message);
        } else {
          notifyError('Failed to open battery optimization settings');
        }
      } catch (error) {
        console.error('Error requesting battery optimization exemption:', error);
        notifyError(`Failed to open battery settings: ${error.message}`);
      }
    },
  },
});

/**
 * Bluetooth contact stored locally
 */
export interface BluetoothContact {
  npub: string;
  peerID: string;
  nickname: string;
  addedAt: number;
  lastInteraction: number;
}
