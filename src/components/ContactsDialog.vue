<template>
  <div class="contacts-dialog">
    <div class="q-pa-md">
      <h6 class="q-mt-none q-mb-md">Contacts</h6>

      <!-- Bluetooth status -->
      <q-banner
        v-if="!bluetoothStore.isActive"
        class="bg-warning text-dark q-mb-md"
        rounded
      >
        <template v-slot:avatar>
          <q-icon name="bluetooth_disabled" />
        </template>
        Bluetooth is off. Turn it on to discover nearby contacts.
        <template v-slot:action>
          <q-btn flat label="Enable" @click="enableBluetooth" />
        </template>
      </q-banner>

      <!-- Mint Selection -->
      <div class="q-mb-md">
        <ChooseMint />
      </div>

      <!-- Balance Display -->
      <div class="q-mb-md">
        <q-badge color="primary" class="text-weight-bold q-pa-sm">
          Available:
          {{ formatCurrency(mintsStore.activeBalance, mintsStore.activeUnit) }}
        </q-badge>
      </div>

      <!-- Empty state -->
      <div
        v-if="
          bluetoothStore.isActive &&
          connectedPeers.length === 0 &&
          offlineFavorites.length === 0
        "
        class="text-center q-py-xl"
      >
        <q-spinner-dots size="3em" color="primary" />
        <div class="q-mt-md text-grey-7">Scanning for contacts...</div>
      </div>

      <!-- Unified contacts list -->
      <q-list
        v-if="
          bluetoothStore.isActive &&
          (connectedPeers.length > 0 || offlineFavorites.length > 0)
        "
        bordered
        separator
        class="rounded-borders"
      >
        <!-- Connected peers section -->
        <template v-if="connectedPeers.length > 0">
          <q-item-label
            header
            class="text-grey-6 q-pa-sm text-uppercase text-caption"
          >
            Nearby ({{ connectedPeers.length }})
          </q-item-label>
          <q-item
            v-for="peer in connectedPeers"
            :key="peer.peerID"
            clickable
            v-ripple
            @click="handlePeerClick(peer)"
            :class="{ 'bg-blue-1': selectedPeerID === peer.peerID }"
          >
            <q-item-section avatar>
              <q-avatar
                :color="peer.isDirect ? 'green' : 'orange'"
                text-color="white"
              >
                <q-icon
                  :name="peer.isDirect ? 'bluetooth_connected' : 'device_hub'"
                />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label>
                {{
                  peer.nickname ||
                  peer.nostrNpub?.substring(0, 16) ||
                  peer.peerID.substring(0, 8)
                }}...
                <q-icon
                  v-if="isMutualFavorite(peer.peerID)"
                  name="favorite"
                  color="pink"
                  size="xs"
                  class="q-ml-xs"
                >
                  <q-tooltip>Mutual favorite</q-tooltip>
                </q-icon>
                <q-icon
                  v-if="peer.canSendViaNostr"
                  name="public"
                  color="primary"
                  size="xs"
                  class="q-ml-xs"
                >
                  <q-tooltip>Send via Nostr available</q-tooltip>
                </q-icon>
              </q-item-label>
              <q-item-label caption>
                {{ peer.isDirect ? "Direct" : "Via mesh" }} •
                {{ formatLastSeen(peer.lastSeen) }}
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
                  <q-tooltip>{{
                    isFavorite(peer.peerID)
                      ? "Remove from favorites"
                      : "Add to favorites"
                  }}</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  dense
                  round
                  icon="send"
                  :color="
                    peer.canSendViaNostr || peer.isConnected ? 'primary' : 'grey'
                  "
                  :disable="!peer.canSendViaNostr && !peer.isConnected"
                  @click.stop="openSendDialog(peer)"
                >
                  <q-tooltip>
                    {{
                      peer.canSendViaNostr
                        ? "Send via Nostr"
                        : peer.isConnected
                        ? "Send via Bluetooth"
                        : "Not available"
                    }}
                  </q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </template>

        <!-- Offline favorites section -->
        <template v-if="offlineFavorites.length > 0">
          <q-item-label
            v-if="connectedPeers.length > 0"
            header
            class="text-grey-6 q-pa-sm text-uppercase text-caption q-mt-md"
          >
            Offline Favorites ({{ offlineFavorites.length }})
          </q-item-label>
          <q-item
            v-for="fav in offlineFavorites"
            :key="fav.peerID"
            clickable
            v-ripple
            @click="handleOfflineFavoriteClick(fav)"
            :class="{ 'bg-blue-1': selectedPeerID === fav.peerID }"
          >
            <q-item-section avatar>
              <q-avatar color="primary" text-color="white">
                <q-icon :name="fav.isMutual ? 'favorite' : 'person'" />
              </q-avatar>
            </q-item-section>

            <q-item-section>
              <q-item-label>
                {{ fav.nickname }}
                <q-icon
                  v-if="fav.isMutual"
                  name="favorite"
                  color="pink"
                  size="xs"
                  class="q-ml-xs"
                >
                  <q-tooltip>Mutual favorite</q-tooltip>
                </q-icon>
                <q-icon
                  v-if="fav.hasNostr && fav.isMutual"
                  name="public"
                  color="primary"
                  size="xs"
                  class="q-ml-xs"
                >
                  <q-tooltip>Send via Nostr available</q-tooltip>
                </q-icon>
              </q-item-label>
              <q-item-label caption>
                <span v-if="fav.npub">
                  {{ formatNpub(fav.npub) }}
                </span>
                <span v-else class="text-warning">
                  <q-icon name="warning" size="xs" /> No Nostr key
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
                  @click.stop="removeFavorite(fav.peerID)"
                >
                  <q-tooltip>Remove from favorites</q-tooltip>
                </q-btn>
                <q-btn
                  flat
                  dense
                  round
                  icon="send"
                  :color="fav.hasNostr && fav.isMutual ? 'primary' : 'grey'"
                  :disable="!(fav.hasNostr && fav.isMutual)"
                  @click.stop="openSendDialogForOffline(fav)"
                >
                  <q-tooltip>
                    {{
                      fav.hasNostr && fav.isMutual
                        ? "Send via Nostr"
                        : "Nostr key required"
                    }}
                  </q-tooltip>
                </q-btn>
              </div>
            </q-item-section>
          </q-item>
        </template>
      </q-list>

      <!-- Send dialog -->
      <q-dialog v-model="showSendDialog" persistent>
        <q-card style="min-width: 400px">
          <q-card-section class="row items-center">
            <q-icon name="send" color="primary" size="md" class="q-mr-sm" />
            <span class="text-h6">Send to {{ sendTarget?.nickname }}</span>
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

            <q-banner
              dense
              class="q-mb-md"
              rounded
              :class="sendViaNostr ? 'bg-info text-white' : 'bg-blue-1'"
            >
              <template v-slot:avatar>
                <q-icon :name="sendViaNostr ? 'public' : 'bluetooth'" />
              </template>
              {{
                sendViaNostr
                  ? "Sending via Nostr - no Bluetooth connection needed"
                  : "Sending via Bluetooth mesh"
              }}
            </q-banner>
          </q-card-section>

          <q-card-actions align="right" class="q-pa-md">
            <q-btn
              flat
              round
              icon="close"
              color="grey"
              @click="closeSendDialog"
            >
              <q-tooltip>Close</q-tooltip>
            </q-btn>
            <q-btn
              color="primary"
              label="Send"
              @click="sendToken"
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
import { defineComponent, ref, computed, onMounted, onUnmounted } from "vue";
import { useBluetoothStore } from "src/stores/bluetooth";
import { useFavoritesStore } from "src/stores/favorites";
import { useWalletStore } from "src/stores/wallet";
import { useMintsStore } from "src/stores/mints";
import { useProofsStore } from "src/stores/proofs";
import { useTokensStore } from "src/stores/tokens";
import { useNostrStore } from "src/stores/nostr";
import { notifySuccess, notifyError } from "src/js/notify";
import { Peer } from "src/plugins/bluetooth-ecash";
import BluetoothEcash from "src/plugins/bluetooth-ecash";
import { nip19 } from "nostr-tools";
import ChooseMint from "src/components/ChooseMint.vue";

interface OfflineFavorite {
  peerID: string;
  nickname: string;
  isMutual: boolean;
  hasNostr: boolean;
  npub?: string;
}

export default defineComponent({
  name: "ContactsDialog",

  emits: ["close"],

  mixins: [window.windowMixin],

  components: {
    ChooseMint,
  },

  setup(props, { emit }) {
    const bluetoothStore = useBluetoothStore();
    const favoritesStore = useFavoritesStore();
    const walletStore = useWalletStore();
    const mintsStore = useMintsStore();
    const proofsStore = useProofsStore();
    const tokensStore = useTokensStore();
    const nostrStore = useNostrStore();

    const selectedPeerID = ref<string | null>(null);
    const showSendDialog = ref(false);
    const sendTarget = ref<any>(null);
    const sendViaNostr = ref(false);
    const sendAmount = ref<number | null>(null);
    const sendMemo = ref<string>("");
    const sending = ref(false);

    const connectedPeers = ref<Array<Peer & { canSendViaNostr?: boolean }>>(
      []
    );
    const offlineFavorites = ref<OfflineFavorite[]>([]);
    const pollInterval = ref<number | null>(null);

    const unit = computed(() => mintsStore.activeUnit);

    // Fetch connected peers with Nostr capability
    const fetchConnectedPeers = async () => {
      try {
        const result = await BluetoothEcash.getAvailablePeers();
        connectedPeers.value = result.peers || [];
      } catch (error) {
        console.error("Failed to fetch connected peers:", error);
        connectedPeers.value = [];
      }
    };

    // Fetch offline favorites
    const fetchOfflineFavorites = async () => {
      try {
        const result = await BluetoothEcash.getOfflineFavorites();
        offlineFavorites.value = result.favorites || [];
      } catch (error) {
        console.error("Failed to fetch offline favorites:", error);
        offlineFavorites.value = [];
      }
    };

    // Refresh contacts periodically
    const startPolling = () => {
      if (pollInterval.value) {
        clearInterval(pollInterval.value);
      }
      pollInterval.value = window.setInterval(async () => {
        if (bluetoothStore.isActive) {
          await fetchConnectedPeers();
          await fetchOfflineFavorites();
        }
      }, 5000);
    };

    const stopPolling = () => {
      if (pollInterval.value) {
        clearInterval(pollInterval.value);
        pollInterval.value = null;
      }
    };

    onMounted(async () => {
      await fetchConnectedPeers();
      await fetchOfflineFavorites();
      if (bluetoothStore.isActive) {
        startPolling();
      }
    });

    onUnmounted(() => {
      stopPolling();
    });

    const formatLastSeen = (timestamp: number): string => {
      const seconds = Math.floor((Date.now() - timestamp) / 1000);
      if (seconds < 60) return "Just now";
      if (seconds < 3600) return `${Math.floor(seconds / 60)}m ago`;
      if (seconds < 86400) return `${Math.floor(seconds / 3600)}h ago`;
      return `${Math.floor(seconds / 86400)}d ago`;
    };

    const formatNpub = (npub: string | null): string => {
      if (!npub) return "No Nostr key";
      return npub.length > 16 ? `${npub.substring(0, 16)}...` : npub;
    };

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

        // Send unfavorite notification
        try {
          if (!nostrStore.seedSignerPublicKey) {
            await nostrStore.walletSeedGenerateKeyPair();
          }

          const hexPubkey =
            nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (hexPubkey) {
            const npub = hexPubkey.startsWith("npub")
              ? hexPubkey
              : nip19.npubEncode(hexPubkey);
            await bluetoothStore.sendTextMessage(
              peer.peerID,
              `[UNFAVORITED]:${npub}`
            );
            console.log(
              `📤 Sent unfavorite notification to ${peer.nickname} with npub: ${npub.substring(0, 16)}...`
            );
          }
        } catch (error) {
          console.error("Failed to send unfavorite notification:", error);
        }

        notifySuccess(`Removed ${peer.nickname} from favorites`);
      } else {
        // Add to favorites
        favoritesStore.addFavorite(
          peer.peerID,
          peer.nickname || "Unknown",
          peer.nostrNpub || null
        );

        // Send favorite request
        try {
          if (!nostrStore.seedSignerPublicKey) {
            await nostrStore.walletSeedGenerateKeyPair();
          }

          const hexPubkey =
            nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (hexPubkey) {
            const npub = hexPubkey.startsWith("npub")
              ? hexPubkey
              : nip19.npubEncode(hexPubkey);
            await bluetoothStore.sendTextMessage(
              peer.peerID,
              `[FAVORITE_REQUEST]:${npub}`
            );
            console.log(
              `📤 Sent favorite request to ${peer.nickname} with npub: ${npub.substring(0, 16)}...`
            );
          }
        } catch (error) {
          console.error("Failed to send favorite request:", error);
        }

        notifySuccess(`Sent favorite request to ${peer.nickname}`);
      }

      // Refresh offline favorites
      await fetchOfflineFavorites();
    };

    const removeFavorite = (peerID: string) => {
      favoritesStore.removeFavorite(peerID);
      notifySuccess(`Removed from favorites`);
      fetchOfflineFavorites();
    };

    const handlePeerClick = (peer: Peer) => {
      selectedPeerID.value = peer.peerID;
    };

    const handleOfflineFavoriteClick = (fav: OfflineFavorite) => {
      selectedPeerID.value = fav.peerID;
    };

    const openSendDialog = (peer: Peer) => {
      sendTarget.value = peer;
      sendAmount.value = null;
      sendMemo.value = "";
      sendViaNostr.value = peer.canSendViaNostr || false;
      showSendDialog.value = true;
    };

    const openSendDialogForOffline = (fav: OfflineFavorite) => {
      sendTarget.value = {
        peerID: fav.peerID,
        nickname: fav.nickname,
        canSendViaNostr: fav.hasNostr && fav.isMutual,
      };
      sendAmount.value = null;
      sendMemo.value = "";
      sendViaNostr.value = fav.hasNostr && fav.isMutual;
      showSendDialog.value = true;
    };

    const closeSendDialog = () => {
      showSendDialog.value = false;
      sendTarget.value = null;
      sendAmount.value = null;
      sendMemo.value = "";
      sendViaNostr.value = false;
    };

    const sendToken = async () => {
      if (!sendTarget.value) {
        notifyError("No target selected");
        return;
      }

      if (!sendAmount.value || sendAmount.value <= 0) {
        notifyError("Please enter a valid amount");
        return;
      }

      // Check if we have sufficient balance
      const actualAmount = Math.floor(
        sendAmount.value * mintsStore.activeUnitCurrencyMultiplyer
      );
      if (actualAmount > mintsStore.activeBalance) {
        notifyError(
          `Insufficient balance. Available: ${formatCurrency(
            mintsStore.activeBalance,
            mintsStore.activeUnit
          )}`
        );
        return;
      }

      sending.value = true;

      try {
        // Create token for sending
        const mintWallet = walletStore.mintWallet(
          mintsStore.activeMintUrl,
          mintsStore.activeUnit
        );

        // Check if we have active proofs
        const activeProofs = mintsStore.activeProofs || [];
        if (activeProofs.length === 0) {
          notifyError("No tokens available. Please receive tokens first.");
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

        // Add to transaction history
        tokensStore.addPendingToken({
          amount: actualAmount,
          token: tokenBase64,
          mint: mintsStore.activeMintUrl,
          unit: unit.value,
          label: sendMemo.value
            ? `${sendViaNostr.value ? "🌐" : "📡"} ${
                sendViaNostr.value ? "Nostr" : "Bluetooth"
              }: ${sendMemo.value}`
            : `${sendViaNostr.value ? "🌐" : "📡"} Sent to ${
                sendTarget.value.nickname
              } via ${sendViaNostr.value ? "Nostr" : "Bluetooth"}`,
        });

        if (sendViaNostr.value) {
          // Send via Nostr
          if (!sendTarget.value.canSendViaNostr) {
            notifyError("Contact does not have Nostr key");
            sending.value = false;
            return;
          }

          if (!nostrStore.pubkey) {
            notifyError(
              "Nostr not configured. Please set up your Nostr key first."
            );
            sending.value = false;
            return;
          }

          // Get npub from offline favorite if needed
          let recipientNpub: string | null = null;
          if (sendTarget.value.peerID && !sendTarget.value.npub) {
            // Try to find in offline favorites
            const fav = offlineFavorites.value.find(
              (f) => f.peerID === sendTarget.value.peerID
            );
            recipientNpub = fav?.npub || null;
          } else {
            recipientNpub = sendTarget.value.npub || null;
          }

          if (!recipientNpub) {
            notifyError("Could not resolve recipient Nostr key");
            sending.value = false;
            return;
          }

          // Build Nostr direct message content
          let messageContent = tokenBase64;
          if (sendMemo.value) {
            messageContent += `\n---\nMemo: ${sendMemo.value}\nAmount: ${
              sendAmount.value
            } ${unit.value}\nFrom: ${nostrStore.pubkey.substring(0, 16)}...`;
          }

          console.log(
            `📤 Sending to npub: ${recipientNpub.substring(0, 20)}...`
          );
          await nostrStore.sendNip04DirectMessage(recipientNpub, messageContent);

          notifySuccess(
            `Sent ${sendAmount.value} ${unit.value} to ${sendTarget.value.nickname} via Nostr!`
          );
        } else {
          // Send via Bluetooth mesh
          const messageId = await bluetoothStore.sendToken({
            token: tokenBase64,
            amount: actualAmount,
            unit: unit.value,
            mint: mintsStore.activeMintUrl,
            peerID: sendTarget.value.peerID,
            memo: sendMemo.value || undefined,
            senderNpub: nostrStore.pubkey || "",
          });

          if (messageId) {
            notifySuccess(
              `Sent ${sendAmount.value} ${unit.value} to ${sendTarget.value.nickname} via Bluetooth!`
            );
          } else {
            notifyError("Failed to send token via Bluetooth");
            sending.value = false;
            return;
          }
        }

        closeSendDialog();
      } catch (error) {
        console.error("Failed to send token:", error);
        notifyError(`Failed to send: ${error}`);
      } finally {
        sending.value = false;
      }
    };

    const enableBluetooth = async () => {
      await bluetoothStore.startService();
      if (bluetoothStore.isActive) {
        startPolling();
        await fetchConnectedPeers();
        await fetchOfflineFavorites();
      }
    };

    return {
      bluetoothStore,
      connectedPeers,
      offlineFavorites,
      selectedPeerID,
      showSendDialog,
      sendTarget,
      sendViaNostr,
      sendAmount,
      sendMemo,
      sending,
      unit,
      isFavorite,
      isMutualFavorite,
      toggleFavorite,
      removeFavorite,
      handlePeerClick,
      handleOfflineFavoriteClick,
      openSendDialog,
      openSendDialogForOffline,
      closeSendDialog,
      sendToken,
      enableBluetooth,
      formatLastSeen,
      formatNpub,
    };
  },
});
</script>

<style scoped>
.contacts-dialog {
  max-width: 600px;
  margin: 0 auto;
}

h6 {
  font-size: 1.2rem;
  font-weight: 500;
}
</style>
