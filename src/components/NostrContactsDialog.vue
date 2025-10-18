<template>
  <div class="nostr-contacts">
    <div class="q-pa-md">
      <h6 class="q-mt-none q-mb-md">Nostr Contacts</h6>

      <!-- No contacts message -->
      <div v-if="contacts.length === 0" class="text-center q-py-xl">
        <q-icon name="person_off" size="4em" color="grey-5" />
        <div class="q-mt-md text-grey-7">No saved contacts yet</div>
        <div class="text-caption text-grey-6 q-mt-sm">
          Add favorites from nearby peers to send via Nostr
        </div>
      </div>

      <!-- Contacts list -->
      <q-list v-if="contacts.length > 0" bordered separator class="rounded-borders">
        <q-item
          v-for="contact in contacts"
          :key="contact.peerNoisePublicKey"
          clickable
          v-ripple
          @click="selectedContact = contact"
          :class="{ 'bg-blue-1': selectedContact?.peerNoisePublicKey === contact.peerNoisePublicKey }"
        >
          <q-item-section avatar>
            <q-avatar color="primary" text-color="white">
              <q-icon :name="contact.theyFavoritedUs ? 'favorite' : 'person'" />
            </q-avatar>
          </q-item-section>

          <q-item-section>
            <q-item-label>
              {{ contact.peerNickname }}
              <q-icon
                v-if="contact.theyFavoritedUs"
                name="favorite"
                color="pink"
                size="xs"
                class="q-ml-xs"
              >
                <q-tooltip>Mutual favorite</q-tooltip>
              </q-icon>
            </q-item-label>
            <q-item-label caption>
              <span v-if="contact.peerNostrNpub">
                {{ formatNpub(contact.peerNostrNpub) }}
              </span>
              <span v-else class="text-warning">
                <q-icon name="warning" size="xs" /> No Nostr key - Bluetooth only
              </span>
            </q-item-label>
          </q-item-section>

          <q-item-section side>
            <div class="row items-center q-gutter-xs">
              <q-btn
                flat
                dense
                round
                size="sm"
                icon="delete"
                color="grey"
                @click.stop="removeFavorite(contact)"
              >
                <q-tooltip>Remove from favorites</q-tooltip>
              </q-btn>
              <q-btn
                flat
                dense
                round
                icon="send"
                :color="contact.peerNostrNpub ? 'primary' : 'grey'"
                :disable="!contact.peerNostrNpub"
                @click.stop="openSendDialog(contact)"
              >
                <q-tooltip>
                  {{ contact.peerNostrNpub ? 'Send ecash via Nostr' : 'Nostr key required for remote send' }}
                </q-tooltip>
              </q-btn>
            </div>
          </q-item-section>
        </q-item>
      </q-list>

      <!-- Send dialog -->
      <q-dialog v-model="showSendDialog" persistent>
        <q-card style="min-width: 400px">
          <q-card-section class="row items-center">
            <q-icon name="send" color="primary" size="md" class="q-mr-sm" />
            <span class="text-h6">Send to {{ sendTarget?.peerNickname }}</span>
          </q-card-section>

          <q-card-section>
            <!-- Amount input -->
            <q-input
              v-model.number="sendAmount"
              type="number"
              label="Amount"
              outlined
              dense
              :suffix="unit"
              class="q-mb-md"
              autofocus
              placeholder="Enter amount"
            >
              <template v-slot:prepend>
                <q-icon name="payments" />
              </template>
            </q-input>

            <!-- Memo input -->
            <q-input
              v-model="sendMemo"
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

            <q-banner dense class="bg-info text-white q-mb-md" rounded>
              <template v-slot:avatar>
                <q-icon name="info" />
              </template>
              Sending via Nostr - no Bluetooth connection needed
            </q-banner>
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md">
            <q-btn flat round icon="close" color="grey" @click="closeSendDialog">
              <q-tooltip>Close</q-tooltip>
            </q-btn>
            <q-btn
              color="primary"
              label="Send"
              @click="sendViaNostr"
              :loading="sending"
              :disable="!sendAmount || sendAmount <= 0"
            />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, computed } from 'vue';
import { useFavoritesStore, FavoriteRelationship } from 'src/stores/favorites';
import { useNostrStore } from 'src/stores/nostr';
import { useWalletStore } from 'src/stores/wallet';
import { useMintsStore } from 'src/stores/mints';
import { useProofsStore } from 'src/stores/proofs';
import { useTokensStore } from 'src/stores/tokens';
import { notifySuccess, notifyError } from 'src/js/notify';

export default defineComponent({
  name: 'NostrContactsDialog',

  setup() {
    const favoritesStore = useFavoritesStore();
    const nostrStore = useNostrStore();
    const walletStore = useWalletStore();
    const mintsStore = useMintsStore();
    const proofsStore = useProofsStore();
    const tokensStore = useTokensStore();

    const selectedContact = ref<FavoriteRelationship | null>(null);
    const showSendDialog = ref(false);
    const sendTarget = ref<FavoriteRelationship | null>(null);
    const sendAmount = ref<number | null>(null);
    const sendMemo = ref<string>('');
    const sending = ref(false);

    const contacts = computed(() => {
      // Get ALL favorites (with and without Nostr npub)
      // Show warning for those without Nostr capability
      return favoritesStore.myFavorites;
    });

    const unit = computed(() => mintsStore.activeUnit);

    const formatNpub = (npub: string | null): string => {
      if (!npub) return 'No Nostr key';
      return npub.length > 16 ? `${npub.substring(0, 16)}...` : npub;
    };

    const openSendDialog = (contact: FavoriteRelationship) => {
      sendTarget.value = contact;
      sendAmount.value = null;
      sendMemo.value = '';
      showSendDialog.value = true;
    };

    const closeSendDialog = () => {
      showSendDialog.value = false;
      sendTarget.value = null;
      sendAmount.value = null;
      sendMemo.value = '';
    };

    const removeFavorite = (contact: FavoriteRelationship) => {
      favoritesStore.removeFavorite(contact.peerNoisePublicKey);
      notifySuccess(`Removed ${contact.peerNickname} from favorites`);
    };

    const sendViaNostr = async () => {
      if (!sendTarget.value || !sendTarget.value.peerNostrNpub) {
        notifyError('Contact does not have Nostr key');
        return;
      }

      if (!sendAmount.value || sendAmount.value <= 0) {
        notifyError('Please enter a valid amount');
        return;
      }

      if (!nostrStore.pubkey) {
        notifyError('Nostr not configured. Please set up your Nostr key first.');
        return;
      }

      sending.value = true;

      try {
        // Create token for sending
        const actualAmount = Math.floor(sendAmount.value * mintsStore.activeUnitCurrencyMultiplyer);
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
          actualAmount,
          true,
          false
        );

        const tokenBase64 = proofsStore.serializeProofs(sendProofs);

        // Add to transaction history FIRST so token is never lost
        tokensStore.addPendingToken({
          amount: actualAmount,
          token: tokenBase64,
          mint: mintsStore.activeMintUrl,
          unit: unit.value,
          label: sendMemo.value ? `📡 Nostr: ${sendMemo.value}` : `📡 Sent to ${sendTarget.value.peerNickname} via Nostr`,
        });
        console.log('💾 Token saved to transaction history (can be recovered via QR)');

        // Build Nostr direct message content
        let messageContent = tokenBase64;
        if (sendMemo.value) {
          messageContent += `\n---\nMemo: ${sendMemo.value}\nAmount: ${sendAmount.value} ${unit.value}\nFrom: ${nostrStore.pubkey.substring(0, 16)}...`;
        }

        // Send via Nostr DM (NIP-04)
        console.log(`📤 Sending to npub: ${sendTarget.value.peerNostrNpub.substring(0, 20)}...`);
        console.log(`📤 Message length: ${messageContent.length} chars`);
        await nostrStore.sendNip04DirectMessage(sendTarget.value.peerNostrNpub, messageContent);

        notifySuccess(`Sent ${sendAmount.value} ${unit.value} to ${sendTarget.value.peerNickname} via Nostr!`);
        closeSendDialog();
      } catch (error) {
        console.error('Failed to send via Nostr:', error);
        notifyError(`Failed to send: ${error}`);
      } finally {
        sending.value = false;
      }
    };

    return {
      contacts,
      selectedContact,
      showSendDialog,
      sendTarget,
      sendAmount,
      sendMemo,
      sending,
      unit,
      formatNpub,
      openSendDialog,
      closeSendDialog,
      removeFavorite,
      sendViaNostr,
    };
  },
});
</script>

<style scoped>
.nostr-contacts {
  max-width: 600px;
  margin: 0 auto;
}
</style>

