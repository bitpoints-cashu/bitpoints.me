<template>
  <div class="nearby-contacts">
    <div class="q-pa-md">
      <h6 class="q-mt-none q-mb-md">Send to Nearby</h6>

      <!-- Bluetooth status -->
      <q-banner v-if="!bluetoothStore.isActive" class="bg-warning text-dark q-mb-md" rounded>
        <template v-slot:avatar>
          <q-icon name="bluetooth_disabled" />
        </template>
        Bluetooth is off. Turn it on to send to nearby devices.
        <template v-slot:action>
          <q-btn flat label="Enable" @click="enableBluetooth" />
        </template>
      </q-banner>

      <!-- Scanning indicator -->
      <div v-if="bluetoothStore.isActive && nearbyPeers.length === 0" class="text-center q-py-xl">
        <q-spinner-dots size="3em" color="primary" />
        <div class="q-mt-md text-grey-7">Scanning for nearby devices...</div>
      </div>

      <!-- Peer list -->
      <q-list v-if="nearbyPeers.length > 0" bordered separator class="rounded-borders">
        <q-item
          v-for="peer in nearbyPeers"
          :key="peer.peerID"
          clickable
          v-ripple
          @click="togglePeerSelection(peer)"
          :class="{ 'bg-blue-1': selectedPeers.has(peer.peerID) }"
        >
          <q-item-section avatar>
            <q-avatar :color="peer.isDirect ? 'green' : 'orange'" text-color="white">
              <q-icon :name="peer.isDirect ? 'bluetooth_connected' : 'device_hub'" />
            </q-avatar>
          </q-item-section>

          <q-item-section>
            <q-item-label>
              {{ peer.nickname || peer.nostrNpub?.substring(0, 16) || peer.peerID.substring(0, 8) }}...
              <q-icon
                v-if="isMutualFavorite(peer.peerID)"
                name="favorite"
                color="pink"
                size="xs"
                class="q-ml-xs"
              >
                <q-tooltip>Mutual favorite</q-tooltip>
              </q-icon>
            </q-item-label>
            <q-item-label caption>
              {{ peer.isDirect ? 'Direct' : 'Via mesh' }} • {{ formatLastSeen(peer.lastSeen) }}
            </q-item-label>
          </q-item-section>

          <q-item-section side>
            <div class="row items-center q-gutter-xs">
              <q-btn
                flat
                dense
                round
                size="sm"
                :icon="isFavorite(peer.peerID) ? 'favorite' : 'favorite_border'"
                :color="isFavorite(peer.peerID) ? 'pink' : 'grey'"
                @click.stop="toggleFavorite(peer)"
              >
                <q-tooltip>{{ isFavorite(peer.peerID) ? 'Remove from favorites' : 'Add to favorites' }}</q-tooltip>
              </q-btn>
              <q-checkbox
                :model-value="selectedPeers.has(peer.peerID)"
                @click.stop="togglePeerSelection(peer)"
                color="primary"
              />
            </div>
          </q-item-section>
        </q-item>
      </q-list>

      <!-- Send controls -->
      <div v-if="nearbyPeers.length > 0" class="q-mt-md">
        <!-- Amount input -->
        <q-input
          v-model.number="amount"
          type="number"
          label="Amount"
          outlined
          dense
          :suffix="unit"
          class="q-mb-md"
          placeholder="Enter amount"
        >
          <template v-slot:prepend>
            <q-icon name="payments" />
          </template>
        </q-input>

        <!-- Memo input -->
        <q-input
          v-model="memo"
          label="Memo (optional)"
          outlined
          dense
          class="q-mb-md"
          placeholder="What's this for?"
        >
          <template v-slot:prepend>
            <q-icon name="note" />
          </template>
        </q-input>

        <!-- Send button -->
        <q-btn
          unelevated
          color="primary"
          class="full-width"
          :disable="selectedPeers.size === 0 || !amount || amount <= 0 || sending"
          :loading="sending"
          @click="sendToPeers"
        >
          <q-icon name="send" class="q-mr-sm" />
          Send {{ amount || '' }} {{ unit }} to {{ selectedPeers.size }} peer{{ selectedPeers.size !== 1 ? 's' : '' }}
        </q-btn>

        <!-- Broadcast button -->
        <q-btn
          flat
          color="primary"
          class="full-width q-mt-sm"
          :disable="!amount || amount <= 0 || sending"
          :loading="sending"
          @click="broadcastToAll"
        >
          <q-icon name="wifi_tethering" class="q-mr-sm" />
          Broadcast to All Nearby
        </q-btn>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, computed } from 'vue';
import { useBluetoothStore } from 'src/stores/bluetooth';
import { useFavoritesStore } from 'src/stores/favorites';
import { useWalletStore } from 'src/stores/wallet';
import { useMintsStore } from 'src/stores/mints';
import { useProofsStore } from 'src/stores/proofs';
import { useTokensStore } from 'src/stores/tokens';
import { useNostrStore } from 'src/stores/nostr';
import { notifySuccess, notifyError } from 'src/js/notify';
import { Peer } from 'src/plugins/bluetooth-ecash';
import { nip19 } from 'nostr-tools';

export default defineComponent({
  name: 'NearbyContactsDialog',

  emits: ['close'],

  setup(props, { emit }) {
    const bluetoothStore = useBluetoothStore();
    const favoritesStore = useFavoritesStore();
    const walletStore = useWalletStore();
    const mintsStore = useMintsStore();
    const proofsStore = useProofsStore();
    const tokensStore = useTokensStore();
    const nostrStore = useNostrStore();

    const selectedPeers = ref(new Set<string>());
    const amount = ref<number | null>(null);
    const memo = ref<string>('');
    const sending = ref(false);

    const nearbyPeers = computed(() => bluetoothStore.sortedPeers);
    const unit = computed(() => mintsStore.activeUnit);

    const togglePeerSelection = (peer: Peer) => {
      if (selectedPeers.value.has(peer.peerID)) {
        selectedPeers.value.delete(peer.peerID);
      } else {
        selectedPeers.value.add(peer.peerID);
      }
      // Trigger reactivity
      selectedPeers.value = new Set(selectedPeers.value);
    };

    const enableBluetooth = async () => {
      await bluetoothStore.startService();
    };

    const sendToPeers = async () => {
      if (!amount.value || amount.value <= 0) {
        notifyError('Please enter a valid amount');
        return;
      }

      if (selectedPeers.value.size === 0) {
        notifyError('Please select at least one peer');
        return;
      }

      sending.value = true;

      try {
        // Create token for sending
        const sendAmount = Math.floor(amount.value * mintsStore.activeUnitCurrencyMultiplyer);
        const mintWallet = walletStore.mintWallet(mintsStore.activeMintUrl, mintsStore.activeUnit);

        // Check if we have active proofs
        const activeProofs = mintsStore.activeProofs || [];
        if (activeProofs.length === 0) {
          notifyError('No tokens available. Please receive tokens first.');
          sending.value = false;
          return;
        }

        const { sendProofs } = await walletStore.send(
          activeProofs,
          mintWallet,
          sendAmount,
          true,
          false
        );

        const tokenBase64 = proofsStore.serializeProofs(sendProofs);

        // Send to each selected peer
        let successCount = 0;
        for (const peerID of selectedPeers.value) {
          console.log('🟢 [UI] About to call bluetoothStore.sendToken for peer:', peerID);
          console.log('🟢 [UI] Token:', tokenBase64.substring(0, 50) + '...');
          console.log('🟢 [UI] Amount:', sendAmount, unit.value);

          const messageId = await bluetoothStore.sendToken({
            token: tokenBase64,
            amount: sendAmount,
            unit: unit.value,
            mint: mintsStore.activeMintUrl,
            peerID: peerID,
            memo: memo.value || undefined,
            senderNpub: nostrStore.pubkey || '',
          });

          console.log('🟢 [UI] sendToken returned:', messageId);

          if (messageId) {
            successCount++;
          }
        }

        if (successCount > 0) {
          // Add to transaction history so token can be viewed/shared via QR
          tokensStore.addPendingToken({
            amount: sendAmount,
            token: tokenBase64,
            mint: mintsStore.activeMintUrl,
            unit: unit.value,
            label: memo.value ? `📡 Bluetooth: ${memo.value}` : '📡 Sent via Bluetooth',
          });

          notifySuccess(`Sent ${amount.value} ${unit.value} to ${successCount} peer${successCount !== 1 ? 's' : ''}`);

          // Reset form
          amount.value = null;
          memo.value = '';
          selectedPeers.value.clear();

          // Close dialog after successful send
          emit('close');
        }

      } catch (e) {
        console.error('Failed to send tokens:', e);
        notifyError('Failed to send tokens');
      } finally {
        sending.value = false;
      }
    };

    const broadcastToAll = async () => {
      if (!amount.value || amount.value <= 0) {
        notifyError('Please enter a valid amount');
        return;
      }

      sending.value = true;

      try {
        // Create token for sending
        const sendAmount = Math.floor(amount.value * mintsStore.activeUnitCurrencyMultiplyer);
        const mintWallet = walletStore.mintWallet(mintsStore.activeMintUrl, mintsStore.activeUnit);

        // Check if we have active proofs
        const activeProofs = mintsStore.activeProofs || [];
        if (activeProofs.length === 0) {
          notifyError('No tokens available. Please receive tokens first.');
          sending.value = false;
          return;
        }

        const { sendProofs } = await walletStore.send(
          activeProofs,
          mintWallet,
          sendAmount,
          true,
          false
        );

        const tokenBase64 = proofsStore.serializeProofs(sendProofs);

        // Broadcast to all nearby peers
        const messageId = await bluetoothStore.sendToken({
          token: tokenBase64,
          amount: sendAmount,
          unit: unit.value,
          mint: mintsStore.activeMintUrl,
          memo: memo.value || undefined,
          senderNpub: nostrStore.pubkey || '',
        });

        if (messageId) {
          // Add to transaction history so token can be viewed/shared via QR
          tokensStore.addPendingToken({
            amount: sendAmount,
            token: tokenBase64,
            mint: mintsStore.activeMintUrl,
            unit: unit.value,
            label: memo.value ? `📡 Broadcast: ${memo.value}` : '📡 Broadcast via Bluetooth',
          });

          notifySuccess(`Broadcasting ${amount.value} ${unit.value} to all nearby devices`);

          // Reset form
          amount.value = null;
          memo.value = '';

          // Close dialog after successful broadcast
          emit('close');
        }

      } catch (e) {
        console.error('Failed to broadcast tokens:', e);
        notifyError('Failed to broadcast tokens');
      } finally {
        sending.value = false;
      }
    };

    const formatLastSeen = (timestamp: number): string => {
      const seconds = Math.floor((Date.now() - timestamp) / 1000);
      if (seconds < 60) return 'Just now';
      if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
      if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
      return `${Math.floor(seconds / 86400)}d ago`;
    };

    // Favorites methods
    const isFavorite = (peerID: string): boolean => {
      return favoritesStore.isFavorite(peerID);
    };

    const isMutualFavorite = (peerID: string): boolean => {
      return favoritesStore.isMutualFavorite(peerID);
    };

    const toggleFavorite = async (peer: Peer) => {
      const isCurrentlyFavorite = isFavorite(peer.peerID);

      if (isCurrentlyFavorite) {
        // Remove from favorites
        favoritesStore.removeFavorite(peer.peerID);

        // Send unfavorite notification via Bluetooth with wallet-derived npub
        try {
          // Generate npub from wallet seed if not already set
          if (!nostrStore.seedSignerPublicKey) {
            await nostrStore.walletSeedGenerateKeyPair();
          }

          const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (hexPubkey) {
            // Convert hex pubkey to npub format using bech32
            const npub = hexPubkey.startsWith('npub') ? hexPubkey : nip19.npubEncode(hexPubkey);
            await bluetoothStore.sendTextMessage(peer.peerID, `[UNFAVORITED]:${npub}`);
            console.log(`📤 Sent unfavorite notification to ${peer.nickname} with npub: ${npub.substring(0, 16)}...`);
          }
        } catch (error) {
          console.error('Failed to send unfavorite notification:', error);
        }

        notifySuccess(`Removed ${peer.nickname} from favorites`);
      } else {
        // Add to favorites
        favoritesStore.addFavorite(
          peer.peerID,
          peer.nickname || 'Unknown',
          peer.nostrNpub || null
        );

        // Send favorite request with our Nostr npub via Bluetooth
        try {
          // Generate npub from wallet seed if not already set
          if (!nostrStore.seedSignerPublicKey) {
            await nostrStore.walletSeedGenerateKeyPair();
          }

          const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (hexPubkey) {
            // Convert hex pubkey to npub format using bech32
            const npub = hexPubkey.startsWith('npub') ? hexPubkey : nip19.npubEncode(hexPubkey);
            await bluetoothStore.sendTextMessage(peer.peerID, `[FAVORITE_REQUEST]:${npub}`);
            console.log(`📤 Sent favorite request to ${peer.nickname} with npub: ${npub.substring(0, 16)}...`);
          }
        } catch (error) {
          console.error('Failed to send favorite request:', error);
        }

        notifySuccess(`Sent favorite request to ${peer.nickname}`);
      }
    };

    return {
      bluetoothStore,
      nearbyPeers,
      selectedPeers,
      amount,
      memo,
      sending,
      unit,
      isFavorite,
      isMutualFavorite,
      toggleFavorite,
      togglePeerSelection,
      enableBluetooth,
      sendToPeers,
      broadcastToAll,
      formatLastSeen,
    };
  },
});
</script>

<style scoped>
.nearby-contacts {
  max-width: 600px;
  margin: 0 auto;
}

h6 {
  font-size: 1.2rem;
  font-weight: 500;
}
</style>

