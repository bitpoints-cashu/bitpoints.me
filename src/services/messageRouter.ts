/**
 * Message Router Service
 * Ported from BitChat's MessageRouter.swift
 * Routes ecash tokens via Bluetooth mesh (preferred) or Nostr fallback (for mutual favorites)
 */

import { useBluetoothStore } from 'src/stores/bluetooth';
import { useFavoritesStore } from 'src/stores/favorites';
import { useNostrStore } from 'src/stores/nostr';
import { notifySuccess, notifyWarning, notifyError } from 'src/js/notify';

interface QueuedToken {
  token: string;
  recipientPeerID: string;
  timestamp: number;
}

export class MessageRouter {
  private outbox: QueuedToken[] = [];
  private bluetoothStore = useBluetoothStore();
  private favoritesStore = useFavoritesStore();
  private nostrStore = useNostrStore();

  /**
   * Send token with automatic routing (Bluetooth preferred, Nostr fallback)
   * Implements BitChat's routing logic from MessageRouter.swift
   */
  async sendToken(
    token: string, 
    recipientPeerID: string,
    recipientNickname: string = 'user'
  ): Promise<{ success: boolean; method: 'bluetooth' | 'nostr' | 'queued' }> {
    
    // 1. Try Bluetooth mesh first (if peer is reachable)
    const isReachable = this.isPeerReachableViaBluetooth(recipientPeerID);
    
    if (isReachable) {
      console.log(`📡 Routing token via Bluetooth mesh to ${recipientPeerID.substring(0, 8)}...`);
      
      try {
        await this.bluetoothStore.sendToken({
          token,
          recipientID: recipientPeerID,
          amount: 0, // Extract from token if needed
          unit: 'sat',
          memo: '',
        });
        
        notifySuccess(`Sent via Bluetooth to ${recipientNickname}!`);
        return { success: true, method: 'bluetooth' };
      } catch (error) {
        console.error('Bluetooth send failed, trying Nostr...', error);
      }
    }

    // 2. Try Nostr if mutual favorite with known npub
    if (this.canSendViaNostr(recipientPeerID)) {
      console.log(`📨 Routing token via Nostr to ${recipientPeerID.substring(0, 8)}...`);
      
      try {
        const favorite = this.favoritesStore.getFavoriteStatus(recipientPeerID);
        if (favorite?.peerNostrNpub) {
          await this.sendTokenViaNostr(token, favorite.peerNostrNpub, recipientNickname);
          
          notifySuccess(`Sent via Nostr to ${recipientNickname} (they'll receive when online)!`);
          return { success: true, method: 'nostr' };
        }
      } catch (error) {
        console.error('Nostr send failed:', error);
        notifyError('Failed to send via Nostr');
      }
    }

    // 3. Queue for later (when Bluetooth connects or Nostr mapping appears)
    console.log(`📦 Queuing token for ${recipientPeerID.substring(0, 8)}... (no Bluetooth, no Nostr mapping)`);
    
    this.outbox.push({
      token,
      recipientPeerID,
      timestamp: Date.now(),
    });

    notifyWarning('Recipient not reachable. Token queued for delivery.');
    return { success: false, method: 'queued' };
  }

  /**
   * Check if peer is reachable via Bluetooth mesh
   */
  private isPeerReachableViaBluetooth(peerID: string): boolean {
    const peer = this.bluetoothStore.nearbyPeers.find(p => p.id === peerID);
    return peer !== undefined && this.bluetoothStore.isActive;
  }

  /**
   * Check if we can send via Nostr (mutual favorite with npub)
   */
  private canSendViaNostr(peerID: string): boolean {
    const favorite = this.favoritesStore.getFavoriteStatus(peerID);
    return favorite !== null && 
           favorite.isFavorite && 
           favorite.theyFavoritedUs && 
           favorite.peerNostrNpub !== null;
  }

  /**
   * Send token via Nostr DM (for mutual favorites)
   */
  private async sendTokenViaNostr(
    token: string, 
    recipientNpub: string,
    recipientNickname: string
  ): Promise<void> {
    // Create Nostr DM with token
    const content = JSON.stringify({
      type: 'BITPOINTS_TOKEN',
      token,
      timestamp: Date.now(),
      senderNpub: this.nostrStore.npub,
    });

    // Send as encrypted Nostr DM (NIP-04 or gift-wrap NIP-17)
    await this.nostrStore.sendEncryptedDM(content, recipientNpub);

    console.log(`📨 Sent token via Nostr to ${recipientNickname} (${recipientNpub.substring(0, 16)}...)`);
  }

  /**
   * Flush outbox when peer becomes available
   * Called when new Bluetooth connection or Nostr mapping discovered
   */
  async flushOutbox(peerID: string) {
    const queued = this.outbox.filter(q => q.recipientPeerID === peerID);
    
    if (queued.length === 0) return;

    console.log(`📬 Flushing ${queued.length} queued tokens for ${peerID.substring(0, 8)}...`);

    for (const item of queued) {
      try {
        await this.sendToken(item.token, item.recipientPeerID);
        
        // Remove from outbox on success
        this.outbox = this.outbox.filter(q => q !== item);
      } catch (error) {
        console.error('Failed to flush queued token:', error);
      }
    }
  }

  /**
   * Get queued tokens count for a peer
   */
  getQueuedCount(peerID: string): number {
    return this.outbox.filter(q => q.recipientPeerID === peerID).length;
  }

  /**
   * Get all queued tokens
   */
  getQueuedTokens(): QueuedToken[] {
    return [...this.outbox];
  }

  /**
   * Clear old queued tokens (older than 24 hours)
   */
  cleanupOutbox() {
    const oneDayAgo = Date.now() - (24 * 60 * 60 * 1000);
    const before = this.outbox.length;
    
    this.outbox = this.outbox.filter(q => q.timestamp > oneDayAgo);
    
    if (this.outbox.length < before) {
      console.log(`🧹 Cleaned up ${before - this.outbox.length} old queued tokens`);
    }
  }
}

export const messageRouter = new MessageRouter();



