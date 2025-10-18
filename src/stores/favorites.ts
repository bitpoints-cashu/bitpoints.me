import { defineStore } from 'pinia';
import { useLocalStorage } from '@vueuse/core';

/**
 * Favorites Persistence Store
 * Ported from BitChat's FavoritesPersistenceService
 * Manages peer favorite relationships for Bluetooth mesh + Nostr fallback
 */

export interface FavoriteRelationship {
  peerNoisePublicKey: string;  // Hex-encoded Noise pubkey
  peerNostrNpub: string | null; // Nostr npub for fallback routing
  peerNickname: string;
  isFavorite: boolean;          // We favorited them
  theyFavoritedUs: boolean;     // They favorited us
  favoritedAt: Date;
  lastUpdated: Date;
}

export interface FavoritePendingRequest {
  peerNoisePublicKey: string;
  peerNickname: string;
  peerNostrNpub: string;
  receivedAt: Date;
}

export const useFavoritesStore = defineStore('favorites', {
  state: () => ({
    favorites: useLocalStorage<Record<string, FavoriteRelationship>>('bitpoints-favorites', {}),
    pendingRequests: useLocalStorage<Record<string, FavoritePendingRequest>>('bitpoints-pending-favorites', {}),
  }),

  getters: {
    /**
     * Get all mutual favorites (both sides favorited)
     */
    mutualFavorites: (state) => {
      return Object.values(state.favorites).filter(
        f => f.isFavorite && f.theyFavoritedUs
      );
    },

    /**
     * Get favorites where we favorited them
     */
    myFavorites: (state) => {
      return Object.values(state.favorites).filter(f => f.isFavorite);
    },

    /**
     * Get favorites with Nostr npub (can route via Nostr)
     */
    favoritesWithNostr: (state) => {
      return Object.values(state.favorites).filter(
        f => f.isFavorite && f.peerNostrNpub !== null
      );
    },

    /**
     * Count of mutual favorites
     */
    mutualCount(): number {
      return this.mutualFavorites.length;
    },

    /**
     * Get all pending favorite requests
     */
    pendingRequestsList: (state) => {
      return Object.values(state.pendingRequests);
    },

    /**
     * Count of pending requests
     */
    pendingCount(): number {
      return this.pendingRequestsList.length;
    },
  },

  actions: {
    /**
     * Add or update a favorite
     */
    addFavorite(
      peerNoisePublicKey: string,
      peerNickname: string,
      peerNostrNpub: string | null = null
    ) {
      console.log(`⭐️ Adding favorite: ${peerNickname} (${peerNoisePublicKey.substring(0, 16)}...)`);

      const existing = this.favorites[peerNoisePublicKey];

      const relationship: FavoriteRelationship = {
        peerNoisePublicKey,
        peerNostrNpub: peerNostrNpub ?? existing?.peerNostrNpub ?? null,
        peerNickname,
        isFavorite: true,
        theyFavoritedUs: existing?.theyFavoritedUs ?? false,
        favoritedAt: existing?.favoritedAt ?? new Date(),
        lastUpdated: new Date(),
      };

      // Log if this creates a mutual favorite
      if (relationship.isFavorite && relationship.theyFavoritedUs) {
        console.log(`💕 Mutual favorite relationship established with ${peerNickname}!`);
      }

      this.favorites[peerNoisePublicKey] = relationship;
    },

    /**
     * Remove a favorite
     */
    removeFavorite(peerNoisePublicKey: string) {
      const existing = this.favorites[peerNoisePublicKey];
      if (!existing) return;

      console.log(`⭐️ Removing favorite: ${existing.peerNickname}`);

      // If they still favorite us, keep the record but mark us as not favoriting
      if (existing.theyFavoritedUs) {
        this.favorites[peerNoisePublicKey] = {
          ...existing,
          isFavorite: false,
          lastUpdated: new Date(),
        };
      } else {
        // Neither side favorites, remove completely
        delete this.favorites[peerNoisePublicKey];
      }
    },

    /**
     * Update when we learn a peer favorited/unfavorited us
     * Called when receiving favorite notification from peer
     */
    updatePeerFavoritedUs(
      peerNoisePublicKey: string,
      favorited: boolean,
      peerNickname?: string,
      peerNostrNpub?: string
    ) {
      const existing = this.favorites[peerNoisePublicKey];
      const displayName = peerNickname ?? existing?.peerNickname ?? 'Unknown';

      console.log(`📨 Received favorite notification: ${displayName} ${favorited ? 'favorited' : 'unfavorited'} us`);

      const relationship: FavoriteRelationship = {
        peerNoisePublicKey,
        peerNostrNpub: peerNostrNpub ?? existing?.peerNostrNpub ?? null,
        peerNickname: displayName,
        isFavorite: existing?.isFavorite ?? false,
        theyFavoritedUs: favorited,
        favoritedAt: existing?.favoritedAt ?? new Date(),
        lastUpdated: new Date(),
      };

      if (!relationship.isFavorite && !relationship.theyFavoritedUs) {
        // Neither side favorites, remove completely
        delete this.favorites[peerNoisePublicKey];
      } else {
        this.favorites[peerNoisePublicKey] = relationship;

        // Check if this creates a mutual favorite
        if (relationship.isFavorite && relationship.theyFavoritedUs) {
          console.log(`💕 Mutual favorite relationship established with ${displayName}!`);
        }
      }
    },

    /**
     * Check if a peer is favorited by us
     */
    isFavorite(peerNoisePublicKey: string): boolean {
      return this.favorites[peerNoisePublicKey]?.isFavorite ?? false;
    },

    /**
     * Check if we have a mutual favorite relationship
     */
    isMutualFavorite(peerNoisePublicKey: string): boolean {
      const fav = this.favorites[peerNoisePublicKey];
      return (fav?.isFavorite && fav?.theyFavoritedUs) ?? false;
    },

    /**
     * Get favorite status for a peer
     */
    getFavoriteStatus(peerNoisePublicKey: string): FavoriteRelationship | null {
      return this.favorites[peerNoisePublicKey] ?? null;
    },

    /**
     * Update Nostr npub for a peer
     */
    updateNostrNpub(peerNoisePublicKey: string, nostrNpub: string) {
      const existing = this.favorites[peerNoisePublicKey];
      if (existing) {
        this.favorites[peerNoisePublicKey] = {
          ...existing,
          peerNostrNpub: nostrNpub,
          lastUpdated: new Date(),
        };
        console.log(`Updated Nostr npub for ${existing.peerNickname}`);
      }
    },

    /**
     * Clear all favorites
     */
    clearAll() {
      console.log('🧹 Clearing all favorites');
      this.favorites = {};
    },

    /**
     * Add a pending favorite request
     */
    addPendingRequest(
      peerNoisePublicKey: string,
      peerNickname: string,
      peerNostrNpub: string
    ) {
      console.log(`📬 [STORE] Adding pending request: ${peerNickname} (${peerNoisePublicKey.substring(0, 16)}...)`);
      console.log(`📬 [STORE] npub: ${peerNostrNpub.substring(0, 16)}...`);

      const request: FavoritePendingRequest = {
        peerNoisePublicKey,
        peerNickname,
        peerNostrNpub,
        receivedAt: new Date(),
      };

      this.pendingRequests[peerNoisePublicKey] = request;
      console.log(`📬 [STORE] Pending request saved. Total count:`, Object.keys(this.pendingRequests).length);
      console.log(`📬 [STORE] Pending requests:`, this.pendingRequests);
    },

    /**
     * Remove a pending request
     */
    removePendingRequest(peerNoisePublicKey: string) {
      console.log(`🗑️ Removing pending request from: ${peerNoisePublicKey.substring(0, 16)}...`);
      delete this.pendingRequests[peerNoisePublicKey];
    },

    /**
     * Accept a pending request and add to favorites
     */
    acceptPendingRequest(peerNoisePublicKey: string): FavoritePendingRequest | null {
      const request = this.pendingRequests[peerNoisePublicKey];
      if (!request) {
        console.warn(`⚠️ No pending request found for ${peerNoisePublicKey}`);
        return null;
      }

      console.log(`✅ Accepting favorite request from: ${request.peerNickname}`);

      // Add to favorites
      this.addFavorite(
        request.peerNoisePublicKey,
        request.peerNickname,
        request.peerNostrNpub
      );

      // Mark that they favorited us
      this.updatePeerFavoritedUs(request.peerNoisePublicKey, true);

      // Remove from pending
      this.removePendingRequest(peerNoisePublicKey);

      return request;
    },
  },
});



