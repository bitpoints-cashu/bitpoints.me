<template>
  <div class="wallet-container">
    <div class="row q-col-gutter-y-sm justify-center q-pt-sm q-pb-sm">
      <div class="col-12 col-sm-11 col-md-8 text-center q-gutter-y-sm">
        <ActivityOrb />
        <NoMintWarnBanner v-if="mints.length == 0" />
        <EcashClaimNotification v-if="isNativeApp" />
        <BalanceView v-if="mints.length > 0" :set-tab="setTab" />
        <div
          class="row items-center justify-center no-wrap q-mb-sm q-mx-none q-px-none q-pt-sm q-pb-sm position-relative"
        >
          <div class="col-6 q-mb-sm flex justify-center items-center">
            <q-btn
              rounded
              dense
              class="q-px-md q-mr-md wallet-action-btn"
              color="primary"
              @click="showReceiveDialog = true"
            >
              <div class="button-content">
                <q-icon name="south_west" size="1.2rem" class="q-mr-xs" />
                <span>{{ $t("WalletPage.actions.receive.label") }}</span>
              </div>
            </q-btn>
          </div>

          <transition appear enter-active-class="animated pulse">
            <div class="scan-button-container">
              <q-btn size="lg" outline color="primary" flat @click="showCamera">
                <ScanIcon size="2em" />
              </q-btn>
            </div>
          </transition>

          <!-- button to showSendDialog -->
          <div class="col-6 q-mb-sm flex justify-center items-center">
            <q-btn
              rounded
              dense
              class="q-px-md q-ml-md wallet-action-btn"
              color="primary"
              @click="showSendDialog = true"
            >
              <div class="button-content">
                <q-icon name="north_east" size="1.2rem" class="q-mr-xs" />
                <span>{{ $t("WalletPage.actions.send.label") }}</span>
              </div>
            </q-btn>
          </div>
          <ReceiveDialog v-model="showReceiveDialog" />
          <SendDialog v-model="showSendDialog" />
        </div>

        <!-- Bluetooth Nearby Sending (Android only) -->
        <div v-if="isNativeApp" class="row justify-center q-gutter-sm q-mt-sm q-mb-md">
          <q-btn
            rounded
            outline
            color="secondary"
            class="q-px-lg"
            @click="showNearbyDialog = true"
          >
            <q-icon name="bluetooth" size="1.2rem" class="q-mr-sm" />
            <span>Send to Nearby</span>
          </q-btn>

          <q-btn
            rounded
            outline
            color="primary"
            class="q-px-lg"
            @click="showContactsDialog = true"
          >
            <q-icon name="contacts" size="1.2rem" class="q-mr-sm" />
            <span>Contacts</span>
            <q-badge v-if="favoritesStore.pendingCount > 0" color="red" floating>
              {{ favoritesStore.pendingCount }}
            </q-badge>
          </q-btn>

          <q-btn
            v-if="favoritesStore.pendingCount > 0"
            rounded
            outline
            color="orange"
            class="q-px-lg"
            @click="showRequestsDialog = true"
          >
            <q-icon name="inbox" size="1.2rem" class="q-mr-sm" />
            <span>Requests</span>
            <q-badge color="red" floating>
              {{ favoritesStore.pendingCount }}
            </q-badge>
          </q-btn>
        </div>

        <!-- Nearby Contacts Dialog -->
        <q-dialog v-model="showNearbyDialog" position="bottom">
          <q-card style="width: 100%; max-width: 600px;">
            <NearbyContactsDialog @close="showNearbyDialog = false" />
            <q-card-actions align="right">
              <q-btn flat round icon="close" color="grey" v-close-popup>
                <q-tooltip>Close</q-tooltip>
              </q-btn>
            </q-card-actions>
          </q-card>
        </q-dialog>

        <!-- Nostr Contacts Dialog -->
        <q-dialog v-model="showContactsDialog" position="bottom">
          <q-card style="width: 100%; max-width: 600px;">
            <NostrContactsDialog />
            <q-card-actions align="right">
              <q-btn flat round icon="close" color="grey" v-close-popup>
                <q-tooltip>Close</q-tooltip>
              </q-btn>
            </q-card-actions>
          </q-card>
        </q-dialog>

        <!-- Favorite Requests Dialog -->
        <q-dialog v-model="showRequestsDialog" position="bottom">
          <q-card style="width: 100%; max-width: 600px;">
            <FavoriteRequestsDialog />
            <q-card-actions align="right">
              <q-btn flat round icon="close" color="grey" v-close-popup>
                <q-tooltip>Close</q-tooltip>
              </q-btn>
            </q-card-actions>
          </q-card>
        </q-dialog>

        <!-- ///////////////////////////////////////////
      ////////////////// TABLES /////////////////
      /////////////////////////////////////////// -->
        <q-expansion-item expand-icon-class="hidden" v-model="expandHistory">
          <template v-slot:header="{ expanded }">
            <q-item-section class="item-center text-center">
              <span
                ><q-icon
                  color="primary"
                  :name="
                    expanded ? 'keyboard_arrow_up' : 'keyboard_arrow_down'
                  "
              /></span>
            </q-item-section>
          </template>
          <q-tabs
            v-model="tab"
            no-caps
            :class="$q.dark.isActive ? 'bg-dark' : 'bg-white'"
          >
            <q-tab
              name="history"
              class="text-secondary"
              :label="$t('WalletPage.tabs.history.label')"
            ></q-tab>
            <!-- <q-tab name="tokens" label="Tokens"></q-tab> -->
            <q-tab
              name="mints"
              class="text-secondary"
              :label="$t('WalletPage.tabs.mints.label')"
            ></q-tab>
          </q-tabs>

          <q-tab-panels
            :class="$q.dark.isActive ? 'bg-dark' : 'bg-white'"
            v-model="tab"
            animated
          >
            <!-- ////////////////// UNIFIED HISTORY LIST ///////////////// -->

            <q-tab-panel name="history">
              <HistoryTable />
            </q-tab-panel>

            <!-- ////////////////////// SETTINGS ////////////////// -->

            <q-tab-panel name="mints" class="q-px-sm">
              <MintSettings />
            </q-tab-panel>
          </q-tab-panels>
        </q-expansion-item>

        <div style="margin-bottom: 0rem; margin-top: 0rem">
          <div class="row q-pt-none">
            <div class="col-12 q-pt-xs">
              <q-btn
                class="q-mx-xs q-px-sm q-my-sm"
                outline
                size="0.6rem"
                v-if="
                  !isNativeApp &&
                  getPwaDisplayMode() == 'browser' &&
                  deferredPWAInstallPrompt != null
                "
                color="primary"
                @click="triggerPwaInstall()"
                ><b>{{ $t("WalletPage.install.text") }}</b
                ><q-tooltip>{{
                  $t("WalletPage.install.tooltip")
                }}</q-tooltip></q-btn
              >
            </div>
          </div>
        </div>

        <iOSPWAPrompt v-if="!isNativeApp" />
        <AndroidPWAPrompt v-if="!isNativeApp" />
      </div>
    </div>

    <!-- FOOTER CREDITS -->
    <div class="footer-section">
      <div class="row justify-center">
        <div class="col-12 col-sm-11 col-md-8 text-center">
          <div class="trails-footer">
            <p class="q-mb-xs text-caption text-grey-5">
              Built with <q-icon name="favorite" color="red" size="xs" /> using
              the open-source
              <a
                href="https://github.com/cashubtc/cashu.me"
                target="_blank"
                class="text-primary"
              >
                cashu.me
              </a>
              wallet
            </p>
            <p class="q-mb-none text-caption text-grey-6">
              Support digital cash development:
              <a href="https://cashu.space" target="_blank" class="text-primary"
                >cashu.space</a
              >
              •
              <a
                href="https://opencash.dev/"
                target="_blank"
                class="text-primary"
                >OpenCash.dev</a
              >
            </p>
          </div>
        </div>
      </div>
    </div>
  </div>

  <!-- BOTTOM LIGHTNING BUTTONS -->

  <!-- DIALOGS  -->

  <!-- INPUT PARSER  -->
  <PayInvoiceDialog v-model="payInvoiceData.show" />

  <!-- QR CODE SCANNER  -->
  <q-dialog v-model="camera.show" backdrop-filter="blur(2px) brightness(60%)">
    <QrcodeReader @decode="decodeQR" />
  </q-dialog>

  <!-- WELCOME DIALOG  -->
  <WelcomeDialog
    :welcome-dialog="welcomeDialog"
    :trigger-pwa-install="triggerPwaInstall"
    :set-tab="setTab"
    :get-pwa-display-mode="getPwaDisplayMode"
    :set-welcome-dialog-seen="setWelcomeDialogSeen"
  />

  <!-- INVOICE DETAILS  -->
  <InvoiceDetailDialog v-model="showInvoiceDetails" />

  <!-- SEND TOKENS DIALOG  -->
  <SendTokenDialog v-model="showSendTokens" />

  <!-- RECEIVE TOKENS DIALOG  -->
  <ReceiveTokenDialog v-model="showReceiveTokens" />
</template>
<style>
* {
  touch-action: manipulation;
}

.keypad {
  display: grid;
  grid-gap: 8px;
  grid-template-columns: repeat(4, 1fr);
  grid-template-rows: repeat(4, 1fr);
}

.keypad .btn {
  height: 100%;
}

.keypad .btn-confirm {
  grid-area: 1 / 4 / 5 / 4;
}

.wallet-action-btn {
  min-width: 140px;
  width: auto;
  white-space: nowrap;
  font-size: 1.2rem;
}

.button-content {
  display: flex;
  align-items: center;
  white-space: nowrap;
}

/* Apply equal widths to wallet action buttons after render */
.equal-width-buttons {
  display: flex;
  justify-content: space-between;
}

.scan-button-container {
  position: absolute;
  z-index: 1;
  padding-bottom: 15px;
}

/* Wallet container */
.wallet-container {
  display: flex;
  flex-direction: column;
  min-height: calc(100vh - 120px); /* Account for header height */
}

/* Footer positioning */
.footer-section {
  margin-top: auto;
  padding: 1rem 0 1.5rem 0;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.trails-footer {
  padding: 0.5rem 0;
}

.trails-footer a {
  color: #6b4423 !important;
  text-decoration: none;
  transition: opacity 0.3s ease;
}

.trails-footer a:hover {
  opacity: 0.8;
  text-decoration: underline;
}
</style>
<script lang="ts">
import { date } from "quasar";
import * as _ from "underscore";
import { shortenString } from "src/js/string-utils";
import token from "src/js/token";

// Vue components
import BalanceView from "components/BalanceView.vue";
import MintSettings from "components/MintSettings.vue";
import HistoryTable from "components/HistoryTable.vue";
import NoMintWarnBanner from "components/NoMintWarnBanner.vue";
import WelcomeDialog from "components/WelcomeDialog.vue";
import SendTokenDialog from "components/SendTokenDialog.vue";
import PayInvoiceDialog from "components/PayInvoiceDialog.vue";
import InvoiceDetailDialog from "components/InvoiceDetailDialog.vue";
import SendDialog from "components/SendDialog.vue";
import ReceiveDialog from "components/ReceiveDialog.vue";
import QrcodeReader from "components/QrcodeReader.vue";
import EcashClaimNotification from "components/EcashClaimNotification.vue";
import NearbyContactsDialog from "components/NearbyContactsDialog.vue";
import NostrContactsDialog from "components/NostrContactsDialog.vue";
import FavoriteRequestsDialog from "components/FavoriteRequestsDialog.vue";
import iOSPWAPrompt from "components/iOSPWAPrompt.vue";
import AndroidPWAPrompt from "components/AndroidPWAPrompt.vue";
import ActivityOrb from "components/ActivityOrb.vue";

// pinia stores
import { mapActions, mapState, mapWritableState } from "pinia";
import { useMintsStore } from "src/stores/mints";
import { useSendTokensStore } from "src/stores/sendTokensStore";
import { useReceiveTokensStore } from "src/stores/receiveTokensStore";
import { useWorkersStore } from "src/stores/workers";
import { useTokensStore } from "src/stores/tokens";
import { useWalletStore } from "src/stores/wallet";
import { useUiStore } from "src/stores/ui";
import { useProofsStore } from "src/stores/proofs";
import { useCameraStore } from "src/stores/camera";
import { useFavoritesStore } from "src/stores/favorites";
import { useBluetoothStore } from "src/stores/bluetooth";
import { useP2PKStore } from "src/stores/p2pk";
import { useNWCStore } from "src/stores/nwc";
import { useNPCStore } from "src/stores/npubcash";
import { useNPCV2Store } from "src/stores/npcv2";
import { useNostrStore } from "src/stores/nostr";
import { usePRStore } from "src/stores/payment-request";
import { useDexieStore } from "src/stores/dexie";

import { useStorageStore } from "src/stores/storage";
import ReceiveTokenDialog from "src/components/ReceiveTokenDialog.vue";
import { useWelcomeStore } from "../stores/welcome";
import { useInvoicesWorkerStore } from "src/stores/invoicesWorker";
import { notifyError, notify } from "../js/notify";

import {
  X as XIcon,
  Banknote as BanknoteIcon,
  Zap as ZapIcon,
  Scan as ScanIcon,
} from "lucide-vue-next";

import { useMigrationsStore } from "src/stores/migrations";

export default {
  mixins: [windowMixin],
  components: {
    BalanceView,
    MintSettings,
    HistoryTable,
    NoMintWarnBanner,
    WelcomeDialog,
    SendTokenDialog,
    ReceiveTokenDialog,
    PayInvoiceDialog,
    InvoiceDetailDialog,
    QrcodeReader,
    SendDialog,
    ReceiveDialog,
    iOSPWAPrompt,
    AndroidPWAPrompt,
    ScanIcon,
    ActivityOrb,
    EcashClaimNotification,
    NearbyContactsDialog,
    NostrContactsDialog,
    FavoriteRequestsDialog,
  },
  data: function () {
    return {
      name: "",
      mintId: "",
      mintName: "",
      deferredPWAInstallPrompt: null,
      showNearbyDialog: false,
      showContactsDialog: false,
      showRequestsDialog: false,
      action: "main",
      parse: {
        show: false,
        invoice: null,
        lnurlpay: null,
        lnurlauth: null,
        data: {
          request: "",
          amount: 0,
          comment: "",
        },
        camera: {
          show: false,
          camera: "auto",
        },
      },
      payments: [],
      paymentsChart: {
        show: false,
      },
      welcomeDialog: {
        show: false,
      },
      baseHost: location.protocol + "//" + location.host,
      baseURL: location.protocol + "//" + location.host + location.pathname,
      credit: 0,
      newName: "",
    };
  },
  computed: {
    ...mapState(useUiStore, ["tickerShort"]),
    favoritesStore() {
      return useFavoritesStore();
    },
    isNativeApp: function () {
      // @ts-ignore
      // Electron should be treated as desktop, not native
      if (window?.Capacitor && typeof window.Capacitor.getPlatform === 'function') {
        const platform = window.Capacitor.getPlatform();
        // Only Android and iOS are truly native
        return platform === 'android' || platform === 'ios';
      }
      return false;
    },
    ...mapWritableState(useUiStore, [
      "showInvoiceDetails",
      "tab",
      "showSendDialog",
      "showReceiveDialog",
    ]),
    ...mapWritableState(useUiStore, ["expandHistory"]),
    ...mapWritableState(useReceiveTokensStore, [
      "showReceiveTokens",
      "receiveData",
    ]),
    ...mapWritableState(useSendTokensStore, ["showSendTokens", "sendData"]),
    ...mapState(useMintsStore, [
      "activeMintUrl",
      "activeProofs",
      "keys",
      "mints",
      "activeMint",
    ]),
    ...mapWritableState(useWalletStore, [
      "invoiceHistory",
      "invoiceData",
      "payInvoiceData",
    ]),
    ...mapWritableState(useMintsStore, ["addMintData", "showAddMintDialog"]),
    ...mapWritableState(useWorkersStore, [
      "invoiceCheckListener",
      "tokensCheckSpendableListener",
    ]),
    ...mapState(useTokensStore, ["historyTokens"]),
    ...mapState(usePRStore, ["enablePaymentRequest"]),
    ...mapWritableState(useCameraStore, ["camera", "hasCamera"]),
    ...mapWritableState(useP2PKStore, ["showP2PKDialog"]),
    ...mapWritableState(useNWCStore, ["showNWCDialog", "nwcEnabled"]),
    pendingPaymentsExist: function () {
      return this.payments.findIndex((payment) => payment.pending) !== -1;
    },

    balance: function () {
      return this.activeProofs
        .map((t) => t)
        .flat()
        .reduce((sum, el) => (sum += el.amount), 0);
    },
  },
  filters: {},
  methods: {
    ...mapActions(useProofsStore, [
      "serializeProofs",
      "getProofsMint",
      "serializeProofsV2",
      "sumProofs",
      "deleteProofs",
    ]),
    ...mapActions(useMintsStore, [
      "activateMintUrl",
      "addMint",
      "assertMintError",
      "getBalance",
      "setActiveProofs",
      "setProofs",
      "getKeysForKeyset",
    ]),
    ...mapActions(useWorkersStore, ["clearAllWorkers", "invoiceCheckWorker", "lightningAddressCheckWorker"]),
    ...mapActions(useTokensStore, ["setTokenPaid"]),
    ...mapActions(useWalletStore, [
      "setInvoicePaid",
      "mint",
      "checkPendingTokens",
      "decodeRequest",
      "initializeMnemonic",
    ]),
    ...mapActions(useCameraStore, ["closeCamera", "showCamera"]),
    ...mapActions(useNWCStore, ["listenToNWCCommands"]),
    ...mapActions(useNPCStore, ["generateNPCConnection", "claimAllTokens"]),
    ...mapActions(useNPCV2Store, [
      "generateNPCV2Connection",
      "getLatestQuotes",
    ]),
    ...mapActions(useNostrStore, [
      "sendNip04DirectMessage",
      "sendNip17DirectMessage",
      "subscribeToNip04DirectMessages",
      "subscribeToNip17DirectMessages",
      "sendNip17DirectMessageToNprofile",
      "initSigner",
    ]),
    ...mapActions(useDexieStore, ["migrateToDexie"]),
    ...mapActions(useStorageStore, ["checkLocalStorage"]),
    ...mapActions(usePRStore, ["createPaymentRequest"]),
    ...mapActions(useInvoicesWorkerStore, [
      "startInvoiceCheckerWorker",
      "checkPendingInvoices",
    ]),
    // TOKEN METHODS
    decodeToken: function (encoded_token) {
      try {
        return token.decode(encoded_token);
      } catch (e) {
        return null;
      }
    },
    getProofs: function (decoded_token) {
      return token.getProofs(decoded_token);
    },
    getMint: function (decoded_token) {
      return token.getMint(decoded_token);
    },
    autoClaimPendingNostrTokens: async function () {
      console.log('🔍 Checking for pending Nostr tokens to auto-claim...');
      const tokensStore = useTokensStore();
      const receiveStore = useReceiveTokensStore();

      // Check if history is initialized
      if (!tokensStore.history || !Array.isArray(tokensStore.history)) {
        console.log('ℹ️ Tokens history not yet initialized, skipping auto-claim');
        return;
      }

      // Find all pending tokens (amount > 0 means not claimed yet)
      const pendingTokens = tokensStore.history.filter(
        (t) => t.amount > 0 && t.token && t.token.length > 0
      );

      console.log(`Found ${pendingTokens.length} pending token(s) in history`);

      for (const pendingToken of pendingTokens) {
        try {
          console.log(`💎 Auto-claiming pending token: ${pendingToken.amount} ${pendingToken.unit}`);
          receiveStore.receiveData.tokensBase64 = pendingToken.token;
          const success = await receiveStore.receiveIfDecodes();
          if (success) {
            console.log(`✅ Auto-claimed ${pendingToken.amount} ${pendingToken.unit}`);
            notifySuccess(`💰 Auto-claimed ${pendingToken.amount} ${pendingToken.unit} from Nostr!`);
          }
        } catch (error) {
          console.warn(`⚠️ Failed to auto-claim token:`, error);
        }
      }

      if (pendingTokens.length > 0) {
        console.log('✅ Finished auto-claiming pending tokens');
      }
    },
    //
    shortenString: function (s) {
      return shortenString(s, 20, 10);
    },
    getTokenList: function () {
      const amounts = this.activeProofs.map((t) => t.amount);
      const counts = {};

      for (const num of amounts) {
        counts[num] = counts[num] ? counts[num] + 1 : 1;
      }
      return Object.keys(counts).map((k) => ({
        value: parseInt(k),
        count: parseInt(counts[k]),
        sum: k * counts[k],
      }));
    },

    paymentTableRowKey: function (row) {
      return row.payment_hash + row.amount;
    },
    showChart: function () {
      this.paymentsChart.show = true;
      this.$nextTick(() => {
        generateChart(this.$refs.canvas, this.payments);
      });
    },
    focusInput(el) {
      // TODO: fix this
      // this.$nextTick(() => this.$refs[el].focus());
    },
    showParseDialog: function () {
      this.payInvoiceData.show = true;
      this.payInvoiceData.invoice = null;
      this.payInvoiceData.lnurlpay = null;
      this.payInvoiceData.domain = "";
      this.payInvoiceData.lnurlauth = null;
      this.payInvoiceData.input.request = "";
      this.payInvoiceData.input.comment = "";
      this.camera.show = false;
      this.focusInput("parseDialogInput");
    },
    showWelcomePage: function () {
      if (!useWelcomeStore().termsAccepted) {
        useWelcomeStore().showWelcome = true;
      }
      if (useWelcomeStore().showWelcome) {
        const currentQuery = window.location.search;
        const currentHash = window.location.hash;
        this.$router.push("/welcome" + currentQuery + currentHash);
      }
    },
    setTab: function (to) {
      this.tab = to;
    },
    decodeQR: function (res) {
      this.camera.data = res;
      this.camera.show = false;
      this.decodeRequest(res);
    },
    /////////////////////////////////// WALLET ///////////////////////////////////
    showInvoiceCreateDialog: async function () {
      console.log("##### showInvoiceCreateDialog");
      this.invoiceData.amount = "";
      this.invoiceData.bolt11 = "";
      this.invoiceData.hash = "";
      this.invoiceData.memo = "";
      this.showInvoiceDetails = true;
    },
    showSendTokensDialog: function () {
      console.log("##### showSendTokensDialog");
      this.sendData.tokens = "";
      this.sendData.tokensBase64 = "";
      this.sendData.amount = null;
      this.sendData.memo = "";
      this.showSendTokens = true;
    },
    hideSendTokensDialog: function () {
      this.showSendTokens = false;
    },
    showReceiveTokensDialog: function () {
      this.receiveData.tokensBase64 = "";
      this.showReceiveTokens = true;
    },

    //////////////////////// MINT //////////////////////////////////////////

    // ////////////// UI HELPERS //////////////

    ////////////// WORKERS //////////////

    ////////////// UI HELPERS /////////////
    registerPWAEventHook: function () {
      // register event listener for PWA install prompt
      window.addEventListener("beforeinstallprompt", (e) => {
        // Prevent the mini-infobar from appearing on mobile
        // e.preventDefault()
        // Stash the event so it can be triggered later.
        this.deferredPWAInstallPrompt = e;
        console.log(
          `'beforeinstallprompt' event was fired.`,
          this.getPwaDisplayMode()
        );
      });
    },
    getPwaDisplayMode: function () {
      const isStandalone = window.matchMedia(
        "(display-mode: standalone)"
      ).matches;
      if (document.referrer.startsWith("android-app://")) {
        return "twa";
      } else if (navigator.standalone || isStandalone) {
        return "standalone";
      }
      return "browser";
    },
    triggerPwaInstall: function () {
      // Show the install prompt
      // Note: this doesn't work with IOS, we do it with iOSPWAPrompt
      this.deferredPWAInstallPrompt.prompt();
      // Wait for the user to respond to the prompt
      this.deferredPWAInstallPrompt.userChoice.then((choiceResult) => {
        if (choiceResult.outcome === "accepted") {
          console.log("User accepted the install prompt");
          this.setWelcomeDialogSeen();
        } else {
          console.log("User dismissed the install prompt");
        }
      });
    },
    registerBroadcastChannel: async function () {
      // uses session storage to identify the tab so we can ignore incoming messages from the same tab
      if (!sessionStorage.getItem("tabId")) {
        sessionStorage.setItem(
          "tabId",
          Math.random().toString(36).substring(2) +
            new Date().getTime().toString(36)
        );
      }
      const tabId = sessionStorage.getItem("tabId");
      const channel = new BroadcastChannel("app_channel");
      channel.postMessage({ type: "new_tab_opened", senderId: tabId });
      channel.onmessage = async (event) => {
        // console.log("Received message in tab " + tabId, event.data);
        if (event.data.senderId === tabId) {
          return; // Ignore the message if it comes from the same tab
        }
        if (event.data.type == "new_tab_opened") {
          channel.postMessage({ type: "already_running", senderId: tabId });
        } else if (event.data.type == "already_running") {
          this.$router.push("/already-running");
        }
      };
    },
    initializeBluetooth: async function () {
      try {
        const bluetoothStore = useBluetoothStore();
        // Only initialize the store (setup event listeners, etc)
        await bluetoothStore.initialize();

        // For desktop PWA: Don't auto-start - Web Bluetooth requires user gesture
        // User MUST click "Connect Device" button in Settings to enable
        if (this.isNativeApp) {
          // Only auto-start for native mobile apps
          await bluetoothStore.startService();
          console.log('Bluetooth mesh service auto-started (native app)');
        } else {
          console.log('💡 Bluetooth ready. Go to Settings → Bluetooth Mesh and click "Connect Device" to enable.');
        }
      } catch (e) {
        console.error('Failed to initialize Bluetooth:', e);
      }
    },
    equalizeButtonWidths: function () {
      this.$nextTick(() => {
        const actionBtns = document.querySelectorAll(".wallet-action-btn");
        if (actionBtns.length >= 2) {
          // Reset widths first
          actionBtns.forEach((btn) => {
            btn.style.width = "auto";
          });

          // Get the maximum width
          let maxWidth = 0;
          actionBtns.forEach((btn) => {
            maxWidth = Math.max(maxWidth, btn.offsetWidth);
          });

          // Apply the maximum width to all buttons
          actionBtns.forEach((btn) => {
            btn.style.width = `${maxWidth}px`;
          });
        }
      });
    },
  },
  watch: {},

  mounted: function () {
    // generate NPC connection
    this.generateNPCConnection();
    this.claimAllTokens();
    this.generateNPCV2Connection();
    this.getLatestQuotes();
    // Start Lightning address check worker
    this.lightningAddressCheckWorker();
    // Initialize Bluetooth service for native apps
    this.initializeBluetooth();
    // Ensure wallet action buttons have equal width
    this.$nextTick(this.equalizeButtonWidths);
    // Add window resize listener to handle responsive layouts
    window.addEventListener("resize", this.equalizeButtonWidths);
  },

  beforeUnmount: function () {
    // Remove event listener when component is destroyed
    window.removeEventListener("resize", this.equalizeButtonWidths);
  },

  created: async function () {
    console.log(`Git commit: ${GIT_COMMIT}`);

    // Initialize and run migrations
    const migrationsStore = useMigrationsStore();
    migrationsStore.initMigrations();
    await migrationsStore.runMigrations();

    // check if another tab is open
    this.registerBroadcastChannel();

    let params = new URL(document.location).searchParams;
    let hash = new URL(document.location).hash;

    // mint url
    if (params.get("mint")) {
      let addMintUrl = params.get("mint");
      await this.setTab("mints");
      this.showAddMintDialog = true;
      this.addMintData = { url: addMintUrl };
    }
    // Auto-activate Trails Coffee mint on first load
    try {
      if (
        !localStorage.getItem("cashu.activeMintUrl") ||
        localStorage.getItem("cashu.activeMintUrl") === ""
      ) {
        await this.activateMintUrl(
          "https://ecash.trailscoffee.com",
          false,
          true
        );
      } else {
        // Ensure Trails Coffee mint is available even if another mint is active
        const mintsStore = useMintsStore();
        const trailsMint = mintsStore.mints.find(
          (m) => m.url === "https://ecash.trailscoffee.com"
        );
        if (!trailsMint) {
          console.log("Adding Trails Coffee mint...");
          const addedMint = await mintsStore.addMint(
            {
              url: "https://ecash.trailscoffee.com",
              nickname: "Trails Coffee",
            },
            false
          );
          console.log("Added mint:", addedMint);
          // The addMint function already activates the mint, but let's ensure it's active
          if (mintsStore.activeMintUrl !== "https://ecash.trailscoffee.com") {
            console.log("Activating Trails Coffee mint...");
            await this.activateMintUrl(
              "https://ecash.trailscoffee.com",
              false,
              true
            );
          }
        } else {
          console.log(
            "Trails Coffee mint already exists, ensuring it's active..."
          );
          if (mintsStore.activeMintUrl !== "https://ecash.trailscoffee.com") {
            await this.activateMintUrl(
              "https://ecash.trailscoffee.com",
              false,
              true
            );
          }
        }
      }
    } catch (error) {
      console.error("Error initializing Trails Coffee mint:", error);
      // Continue with app initialization even if mint setup fails
    }

    console.log("Mint URL " + this.activeMintUrl);
    console.log("Wallet URL " + this.baseURL);

    // Debug: Check if mint has keysets
    try {
      const mintsStore = useMintsStore();
      const activeMint = mintsStore.mints.find(
        (m) => m.url === this.activeMintUrl
      );
      if (activeMint) {
        console.log("Active mint keysets:", activeMint.keysets);
        console.log("Active mint keys:", activeMint.keys);

        // If no keysets, try to fetch them again
        if (!activeMint.keysets || activeMint.keysets.length === 0) {
          console.log("No keysets found, attempting to fetch...");
          try {
            await mintsStore.fetchMintKeys(activeMint);
            console.log("Keysets fetched successfully:", activeMint.keysets);
          } catch (error) {
            console.error("Failed to fetch keysets:", error);
          }
        }
      } else {
        console.log("No active mint found");
      }
    } catch (error) {
      console.error("Error in debug section:", error);
    }

    // get token to receive tokens from a link
    if (params.get("token") || hash.includes("token")) {
      let tokenBase64 = params.get("token") || hash.split("token=")[1];
      // make sure to react only to tokens not in the users history
      let seen = false;
      for (var i = 0; i < this.historyTokens.length; i++) {
        var thisToken = this.historyTokens[i].token;
        if (thisToken == tokenBase64 && this.historyTokens[i].amount > 0) {
          seen = true;
        }
      }
      if (!seen) {
        // show receive token dialog
        this.receiveData.tokensBase64 = tokenBase64;
        this.showReceiveTokens = true;
      }
    }

    // get lightning invoice from a link
    if (params.get("lightning")) {
      this.showParseDialog();
      this.payInvoiceData.input.request = params.get("lightning");
    }

    // Clear all parameters from URL without refreshing the page
    /*
    window.history.pushState(
      {},
      document.title,
      window.location.href.split("?")[0].split("#")[0]
    );
    */
    console.log(`location.hash: ${window.location.hash}`);

    // startup tasks

    // debug console
    useUiStore().enableDebugConsole();

    // migrate to dexie
    await this.migrateToDexie();

    // check local storage
    this.checkLocalStorage();

    // PWA install hook
    this.registerPWAEventHook();

    // generate new mnemonic
    this.initializeMnemonic();

    this.initSigner();

    // show welcome dialog
    this.showWelcomePage();

    // listen to NWC commands if enabled
    if (this.nwcEnabled) {
      this.listenToNWCCommands();
    }

    if (this.enablePaymentRequest) {
      this.subscribeToNip17DirectMessages();
    }

    // Subscribe to NIP-04 DMs for Nostr contacts feature
    console.log('🔔 Subscribing to NIP-04 DMs for contacts...');
    this.subscribeToNip04DirectMessages();

    // Auto-claim any pending Nostr tokens from history
    this.autoClaimPendingNostrTokens();

    // start invoice checker worker
    this.startInvoiceCheckerWorker();

    // reconnect all websockets
    this.checkPendingInvoices();
  },
};
</script>
