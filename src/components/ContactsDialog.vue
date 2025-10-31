<template>
  <q-dialog
    :model-value="modelValue"
    @update:model-value="$emit('update:modelValue', $event)"
    position="bottom"
    :maximized="$q.screen.lt.sm"
    transition-show="slide-up"
    transition-hide="slide-down"
    backdrop-filter="blur(2px) brightness(60%)"
  >
    <q-card class="bg-grey-10 text-white full-width-card q-pb-lg" style="max-height: 80vh; display: flex; flex-direction: column;">
      <q-card-section class="row items-center q-pb-sm" style="flex-shrink: 0;">
        <q-btn flat round dense v-close-popup class="q-ml-sm" color="primary">
          <XIcon />
        </q-btn>
        <div class="col text-center">
          <span class="text-h6">Contacts</span>
        </div>
        <div class="q-mr-sm" style="width: 40px;"></div>
      </q-card-section>
      
      <q-card-section style="flex: 1; overflow-y: auto; min-height: 0;" class="q-pa-md">
        <div class="contacts-dialog">
          <!-- Bluetooth status (only show if Bluetooth is available) -->
      <q-banner
        v-if="isBluetoothEcashAvailable && !bluetoothStore.isActive"
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

      <!-- PWA info banner (when Bluetooth not available but QR code works) -->
      <q-banner
        v-if="!isBluetoothEcashAvailable"
        class="bg-info text-white q-mb-md"
        rounded
      >
        <template v-slot:avatar>
          <q-icon name="qr_code" />
        </template>
        Use QR codes to add contacts without Bluetooth.
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

      <!-- Empty state (only show if Bluetooth is active and available) -->
      <div
        v-if="
          isBluetoothEcashAvailable &&
          bluetoothStore.isActive &&
          connectedPeers.length === 0 &&
          offlineFavorites.length === 0
        "
        class="text-center q-py-xl"
      >
        <q-spinner-dots size="3em" color="primary" />
        <div class="q-mt-md text-grey-7">Scanning for contacts...</div>
      </div>

      <!-- Empty state for PWA (no Bluetooth, no contacts) -->
      <div
        v-if="
          !isBluetoothEcashAvailable &&
          offlineFavorites.length === 0
        "
        class="text-center q-py-xl"
      >
        <q-icon name="qr_code" size="3em" color="primary" />
        <div class="q-mt-md text-grey-7">Use QR codes to add contacts</div>
      </div>

      <!-- Unified contacts list -->
      <q-list
        v-if="
          offlineFavorites.length > 0 ||
          (isBluetoothEcashAvailable && bluetoothStore.isActive && connectedPeers.length > 0)
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
                  :icon="
                    isFavorite(peer.peerID) ? 'favorite' : 'favorite_border'
                  "
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
                    peer.canSendViaNostr || peer.isConnected
                      ? 'primary'
                      : 'grey'
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
                <span v-if="fav.npub" class="text-positive">
                  <q-icon name="check_circle" size="xs" /> Nostr messaging available
                </span>
                <span v-else class="text-grey-6">
                  <q-icon name="info" size="xs" /> Bluetooth only
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

      <!-- QR Code Exchange Buttons -->
      <div class="row q-gutter-sm q-mt-md q-mb-md">
        <q-btn
          outline
          color="primary"
          icon="qr_code"
          label="My QR Code"
          class="col"
          @click="showQRCodeDialogHandler"
        />
        <q-btn
          outline
          color="secondary"
          icon="camera_alt"
          label="Scan QR Code"
          class="col"
          @click="showScanDialog = true"
        />
      </div>

      <!-- QR Code Display Dialog -->
      <q-dialog v-model="showQRCodeDialog">
        <q-card style="min-width: 350px">
          <q-card-section class="text-center">
            <div class="text-h6 q-mb-md">My Contact QR Code</div>
            <div v-if="qrCodeData" class="q-mb-md">
              <vue-qrcode
                :value="qrCodeData"
                :options="{ width: 300 }"
                class="rounded-borders"
              />
              <div class="q-mt-md text-body2">
                <strong>{{ bluetoothStore.nickname }}</strong>
              </div>
              <div class="q-mt-xs text-caption text-grey-6">
                Share this QR code to add each other as contacts
              </div>
            </div>
            <div v-else class="q-pa-lg">
              <q-spinner-dots size="3em" color="primary" />
              <div class="q-mt-md">Generating QR code...</div>
            </div>
          </q-card-section>
          <q-card-actions align="right">
            <q-btn
              flat
              round
              icon="close"
              color="grey"
              @click="showQRCodeDialog = false"
            >
              <q-tooltip>Close</q-tooltip>
            </q-btn>
          </q-card-actions>
        </q-card>
      </q-dialog>

      <!-- QR Code Scan Dialog -->
      <q-dialog v-model="showScanDialog" persistent>
        <q-card style="width: 100%; max-width: 600px">
          <q-card-section class="text-center">
            <div class="text-h6 q-mb-md">Scan Contact QR Code</div>
            <QrcodeReader @decode="handleQRCodeScanned" />
          </q-card-section>
          <q-card-actions align="right">
            <q-btn
              flat
              round
              icon="close"
              color="grey"
              @click="showScanDialog = false"
            >
              <q-tooltip>Close</q-tooltip>
            </q-btn>
          </q-card-actions>
        </q-card>
      </q-dialog>

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
      </q-card-section>
    </q-card>
  </q-dialog>
</template>

<script lang="ts">
import { defineComponent, ref, computed, onMounted, onUnmounted, nextTick } from "vue";
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
import { Capacitor } from "@capacitor/core";
import { nip19 } from "nostr-tools";
import ChooseMint from "src/components/ChooseMint.vue";
import VueQrcode from "@chenfengyuan/vue-qrcode";
import QrcodeReader from "src/components/QrcodeReader.vue";
import { X as XIcon } from "lucide-vue-next";

interface OfflineFavorite {
  peerID: string;
  nickname: string;
  isMutual: boolean;
  hasNostr: boolean;
  npub?: string;
}

export default defineComponent({
  name: "ContactsDialog",

  props: {
    modelValue: {
      type: Boolean,
      default: false,
    },
  },

  emits: ["update:modelValue"],

  mixins: [window.windowMixin],

  components: {
    ChooseMint,
    VueQrcode,
    QrcodeReader,
    XIcon,
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
    const showQRCodeDialog = ref(false);
    const showScanDialog = ref(false);
    const qrCodeData = ref<string | null>(null);

    const connectedPeers = ref<Array<Peer & { canSendViaNostr?: boolean }>>([]);
    const offlineFavorites = ref<OfflineFavorite[]>([]);
    const pollInterval = ref<number | null>(null);

    const unit = computed(() => mintsStore.activeUnit);

    // Check if BluetoothEcash plugin is available (native only, not web)
    const isBluetoothEcashAvailable = computed(() => {
      return Capacitor.isNativePlatform();
    });

    // Fetch connected peers with Nostr capability
    const fetchConnectedPeers = async () => {
      if (!isBluetoothEcashAvailable.value) {
        connectedPeers.value = [];
        return;
      }
      try {
        const result = await BluetoothEcash.getAvailablePeers();
        connectedPeers.value = result.peers || [];
      } catch (error) {
        console.error("Failed to fetch connected peers:", error);
        connectedPeers.value = [];
      }
    };

    // Fetch offline favorites (from Bluetooth + QR code contacts)
    const fetchOfflineFavorites = async () => {
      let bluetoothFavorites: any[] = [];
      if (isBluetoothEcashAvailable.value) {
        try {
          const result = await BluetoothEcash.getOfflineFavorites();
          bluetoothFavorites = result.favorites || [];
        } catch (error) {
          console.error("Failed to fetch offline favorites from Bluetooth:", error);
          // Continue with QR code contacts only
        }
      }
      
      try {
        
        // Also get QR code contacts from favoritesStore (mutual favorites with npub)
        const qrCodeFavorites = favoritesStore.mutualFavorites
          .filter((fav) => fav.peerNostrNpub !== null)
          .map((fav) => {
            // Check if this is already in Bluetooth favorites
            const existsInBluetooth = bluetoothFavorites.some(
              (bf) => bf.peerID === fav.peerNoisePublicKey
            );
            if (existsInBluetooth) {
              return null; // Skip, already in Bluetooth favorites
            }
            
            return {
              peerID: fav.peerNoisePublicKey,
              nickname: fav.peerNickname,
              isMutual: fav.isFavorite && fav.theyFavoritedUs,
              hasNostr: fav.peerNostrNpub !== null,
              npub: fav.peerNostrNpub || undefined,
            };
          })
          .filter((fav): fav is OfflineFavorite => fav !== null);
        
        // Combine and deduplicate
        const combined = [...bluetoothFavorites, ...qrCodeFavorites];
        // Remove duplicates by peerID
        const uniqueMap = new Map<string, OfflineFavorite>();
        combined.forEach((fav) => {
          if (!uniqueMap.has(fav.peerID)) {
            uniqueMap.set(fav.peerID, fav);
          }
        });
        
        offlineFavorites.value = Array.from(uniqueMap.values());
      } catch (error) {
        console.error("Failed to fetch offline favorites:", error);
        // Fallback to just QR code contacts from favoritesStore
        offlineFavorites.value = favoritesStore.mutualFavorites
          .filter((fav) => fav.peerNostrNpub !== null)
          .map((fav) => ({
            peerID: fav.peerNoisePublicKey,
            nickname: fav.peerNickname,
            isMutual: fav.isFavorite && fav.theyFavoritedUs,
            hasNostr: fav.peerNostrNpub !== null,
            npub: fav.peerNostrNpub || undefined,
          }));
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
      // Use nextTick to ensure dialog is fully rendered before fetching
      // This prevents UI freezing
      await nextTick();
      
      // Always fetch offline favorites (includes QR code contacts)
      // Use try-catch to prevent errors from freezing the UI
      try {
        await fetchOfflineFavorites();
      } catch (error) {
        console.error("Error fetching offline favorites:", error);
        // Set empty array on error to prevent UI freeze
        offlineFavorites.value = [];
      }
      
      // Only fetch connected peers if Bluetooth is available
      if (isBluetoothEcashAvailable.value) {
        try {
          await fetchConnectedPeers();
          if (bluetoothStore.isActive) {
            startPolling();
          }
        } catch (error) {
          console.error("Error fetching connected peers:", error);
          connectedPeers.value = [];
        }
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

          const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (hexPubkey) {
            const npub = hexPubkey.startsWith("npub")
              ? hexPubkey
              : nip19.npubEncode(hexPubkey);
            await bluetoothStore.sendTextMessage(
              peer.peerID,
              `[UNFAVORITED]:${npub}`
            );
            console.log(
              `📤 Sent unfavorite notification to ${
                peer.nickname
              } with npub: ${npub.substring(0, 16)}...`
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

          const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (hexPubkey) {
            const npub = hexPubkey.startsWith("npub")
              ? hexPubkey
              : nip19.npubEncode(hexPubkey);
            await bluetoothStore.sendTextMessage(
              peer.peerID,
              `[FAVORITE_REQUEST]:${npub}`
            );
            console.log(
              `📤 Sent favorite request to ${
                peer.nickname
              } with npub: ${npub.substring(0, 16)}...`
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
          await nostrStore.sendNip04DirectMessage(
            recipientNpub,
            messageContent
          );

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
      if (!isBluetoothEcashAvailable.value) {
        notifyError("Bluetooth is not available in this environment");
        return;
      }
      await bluetoothStore.startService();
      if (bluetoothStore.isActive) {
        startPolling();
        await fetchConnectedPeers();
        await fetchOfflineFavorites();
      }
    };

    // Generate QR code data for contact exchange
    const generateQRCodeData = async (): Promise<string | null> => {
      try {
        // Ensure npub is generated
        if (!nostrStore.seedSignerPublicKey) {
          await nostrStore.walletSeedGenerateKeyPair();
        }

        const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
        if (!hexPubkey) {
          notifyError("Nostr key not available. Please configure Nostr first.");
          return null;
        }

        // Convert hex pubkey to npub format
        const npub = hexPubkey.startsWith("npub")
          ? hexPubkey
          : nip19.npubEncode(hexPubkey);

        // Create QR code JSON with npub and nickname
        const qrData = {
          type: "contact",
          npub: npub,
          nickname: bluetoothStore.nickname,
        };

        return JSON.stringify(qrData);
      } catch (error) {
        console.error("Failed to generate QR code data:", error);
        notifyError("Failed to generate QR code");
        return null;
      }
    };

    // Show QR code dialog and generate QR code
    const showQRCodeDialogHandler = async () => {
      showQRCodeDialog.value = true;
      qrCodeData.value = null;
      const data = await generateQRCodeData();
      qrCodeData.value = data;
    };

    // Handle scanned QR code
    const handleQRCodeScanned = async (scannedData: string) => {
      try {
        // Close scan dialog
        showScanDialog.value = false;

        // Parse JSON data
        let contactData: { type?: string; npub?: string; nickname?: string };
        try {
          contactData = JSON.parse(scannedData);
        } catch (error) {
          notifyError("Invalid QR code format. Expected contact QR code.");
          return;
        }

        // Validate QR code type
        if (contactData.type !== "contact") {
          notifyError("Invalid QR code type. This is not a contact QR code.");
          return;
        }

        // Validate required fields
        if (!contactData.npub) {
          notifyError("Invalid QR code. Missing Nostr public key.");
          return;
        }

        if (!contactData.nickname || contactData.nickname.trim() === "") {
          notifyError("Invalid QR code. Missing nickname.");
          return;
        }

        // Extract npub and nickname
        const scannedNpub = contactData.npub;
        const scannedNickname = contactData.nickname.trim();

        // Check if already a favorite (by npub)
        const existingFavorites = Object.values(favoritesStore.favorites);
        const existingFavorite = existingFavorites.find(
          (fav) => fav.peerNostrNpub === scannedNpub
        );

        if (existingFavorite) {
          // Already favorited - check if mutual
          if (existingFavorite.isFavorite && existingFavorite.theyFavoritedUs) {
            notifySuccess(
              `${scannedNickname} is already your mutual favorite!`
            );
          } else {
            // Update to mutual favorite
            favoritesStore.updatePeerFavoritedUs(
              existingFavorite.peerNoisePublicKey,
              true
            );
            notifySuccess(
              `💕 You and ${scannedNickname} are now mutual favorites!`
            );
          }
          return;
        }

        // Generate a peerID from npub (use first 32 hex chars of npub hash as peerID)
        // Since we don't have a real Bluetooth peerID, we'll use a derived one
        const npubHash = await crypto.subtle.digest(
          "SHA-256",
          new TextEncoder().encode(scannedNpub)
        );
        const hashArray = Array.from(new Uint8Array(npubHash));
        const peerID = hashArray
          .slice(0, 16)
          .map((b) => b.toString(16).padStart(2, "0"))
          .join("");

        // Add as favorite and mark as mutual (since they showed their QR code)
        favoritesStore.addFavorite(peerID, scannedNickname, scannedNpub);
        favoritesStore.updatePeerFavoritedUs(peerID, true);

        notifySuccess(
          `💕 Added ${scannedNickname} as mutual favorite! You can now send messages via Nostr.`
        );

        // Refresh offline favorites
        await fetchOfflineFavorites();
      } catch (error) {
        console.error("Failed to process scanned QR code:", error);
        notifyError("Failed to add contact. Please try again.");
      }
    };

    // Helper function for formatting currency
    const formatCurrency = (amount: number, unit: string): string => {
      if (!amount) return `0 ${unit}`;
      const formatted = (amount / mintsStore.activeUnitCurrencyMultiplyer).toFixed(2);
      return `${formatted} ${unit}`;
    };

    return {
      bluetoothStore,
      mintsStore,
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
      formatCurrency,
      showQRCodeDialog,
      showQRCodeDialogHandler,
      qrCodeData,
      showScanDialog,
      handleQRCodeScanned,
      isBluetoothEcashAvailable,
    };
  },
});
</script>

<style lang="scss" scoped>
.contacts-dialog {
  max-width: 600px;
  margin: 0 auto;
  width: 100%;
}

.q-dialog__inner > div {
  border-top-left-radius: 20px !important;
  border-top-right-radius: 20px !important;
  border-bottom-left-radius: 0px !important;
  border-bottom-right-radius: 0px !important;
}
</style>
