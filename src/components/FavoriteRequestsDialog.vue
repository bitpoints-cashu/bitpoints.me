<template>
  <div class="favorite-requests">
    <div class="q-pa-md">
      <h6 class="q-mt-none q-mb-md">Favorite Requests</h6>

      <!-- No requests message -->
      <div v-if="pendingRequests.length === 0" class="text-center q-py-xl">
        <q-icon name="inbox" size="4em" color="grey-5" />
        <div class="q-mt-md text-grey-7">No pending requests</div>
        <div class="text-caption text-grey-6 q-mt-sm">
          When someone favorites you, it will appear here
        </div>
      </div>

      <!-- Requests list -->
      <q-list v-if="pendingRequests.length > 0" bordered separator class="rounded-borders">
        <q-item
          v-for="request in pendingRequests"
          :key="request.peerNoisePublicKey"
        >
          <q-item-section avatar>
            <q-avatar color="primary" text-color="white">
              <q-icon name="person_add" />
            </q-avatar>
          </q-item-section>

          <q-item-section>
            <q-item-label>{{ request.peerNickname }}</q-item-label>
            <q-item-label caption>
              {{ formatNpub(request.peerNostrNpub) }}
            </q-item-label>
            <q-item-label caption class="text-grey-6 q-mt-xs">
              {{ formatTime(request.receivedAt) }}
            </q-item-label>
          </q-item-section>

          <q-item-section side>
            <div class="row items-center q-gutter-xs">
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="check"
                color="positive"
                @click="acceptRequest(request)"
              >
                <q-tooltip>Accept</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="close"
                color="grey"
                @click="ignoreRequest(request)"
              >
                <q-tooltip>Ignore</q-tooltip>
              </q-btn>
            </div>
          </q-item-section>
        </q-item>
      </q-list>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, computed } from 'vue';
import { useFavoritesStore, FavoritePendingRequest } from 'src/stores/favorites';
import { useBluetoothStore } from 'src/stores/bluetooth';
import { useNostrStore } from 'src/stores/nostr';
import { notifySuccess } from 'src/js/notify';
import { nip19 } from 'nostr-tools';
import { formatDistanceToNow } from 'date-fns';

export default defineComponent({
  name: 'FavoriteRequestsDialog',

  setup() {
    const favoritesStore = useFavoritesStore();
    const bluetoothStore = useBluetoothStore();
    const nostrStore = useNostrStore();

    const pendingRequests = computed(() => favoritesStore.pendingRequestsList);

    const formatNpub = (npub: string) => {
      if (!npub) return 'No Nostr key';
      return `${npub.substring(0, 12)}...${npub.substring(npub.length - 4)}`;
    };

    const formatTime = (date: Date) => {
      try {
        return formatDistanceToNow(new Date(date), { addSuffix: true });
      } catch (e) {
        return 'Recently';
      }
    };

    const acceptRequest = async (request: FavoritePendingRequest) => {
      try {
        // Accept the request (adds to favorites, removes from pending)
        favoritesStore.acceptPendingRequest(request.peerNoisePublicKey);

        // Send acceptance notification back to peer with our npub
        if (!nostrStore.seedSignerPublicKey) {
          await nostrStore.walletSeedGenerateKeyPair();
        }

        const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
        if (hexPubkey) {
          const npub = hexPubkey.startsWith('npub') ? hexPubkey : nip19.npubEncode(hexPubkey);
          await bluetoothStore.sendTextMessage(request.peerNoisePublicKey, `[FAVORITE_ACCEPTED]:${npub}`);
          console.log(`📤 Sent favorite acceptance to ${request.peerNickname} with npub: ${npub.substring(0, 16)}...`);
        }

        notifySuccess(`💕 You and ${request.peerNickname} are now mutual favorites!`);
      } catch (error) {
        console.error('Failed to accept favorite request:', error);
      }
    };

    const ignoreRequest = (request: FavoritePendingRequest) => {
      favoritesStore.removePendingRequest(request.peerNoisePublicKey);
      notifySuccess(`Ignored request from ${request.peerNickname}`);
    };

    return {
      pendingRequests,
      formatNpub,
      formatTime,
      acceptRequest,
      ignoreRequest,
    };
  },
});
</script>

<style scoped>
.favorite-requests {
  min-width: 300px;
  max-width: 600px;
}
</style>

