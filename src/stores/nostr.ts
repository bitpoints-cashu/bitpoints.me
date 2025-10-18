import { defineStore } from "pinia";
import NDK, {
  NDKEvent,
  NDKSigner,
  NDKNip07Signer,
  NDKNip46Signer,
  NDKFilter,
  NDKPrivateKeySigner,
  NostrEvent,
  NDKKind,
  NDKRelaySet,
  NDKRelay,
  NDKTag,
  ProfilePointer,
} from "@nostr-dev-kit/ndk";
import { nip04, nip19, nip44 } from "nostr-tools";
import { bytesToHex, hexToBytes } from "@noble/hashes/utils"; // already an installed dependency
import { useWalletStore } from "./wallet";
import { generateSecretKey, getPublicKey } from "nostr-tools";
import { useLocalStorage } from "@vueuse/core";
import { useSettingsStore } from "./settings";
import { useReceiveTokensStore } from "./receiveTokensStore";
import {
  getEncodedTokenV4,
  PaymentRequestPayload,
  Token,
} from "@cashu/cashu-ts";
import { useTokensStore } from "./tokens";
import {
  notifyApiError,
  notifyError,
  notifySuccess,
  notifyWarning,
  notify,
} from "../js/notify";
import { useSendTokensStore } from "./sendTokensStore";
import { usePRStore } from "./payment-request";
import token from "../js/token";
import { HistoryToken } from "./tokens";

type MintRecommendation = {
  url: string;
  count: number;
};

type NostrEventLog = {
  id: string;
  created_at: number;
};

export enum SignerType {
  NIP07 = "NIP07",
  NIP46 = "NIP46",
  PRIVATEKEY = "PRIVATEKEY",
  SEED = "SEED",
}

export const useNostrStore = defineStore("nostr", {
  state: () => ({
    connected: false,
    pubkey: useLocalStorage<string>("cashu.ndk.pubkey", ""),
    relays: useLocalStorage<string[]>(
      "cashu.nostr.relays",
      useSettingsStore().defaultNostrRelays
    ),
    ndk: {} as NDK,
    signerType: useLocalStorage<SignerType>(
      "cashu.ndk.signerType",
      SignerType.SEED
    ),
    nip07signer: {} as NDKNip07Signer,
    nip46Token: useLocalStorage<string>("cashu.ndk.nip46Token", ""),
    nip46signer: {} as NDKNip46Signer,
    privateKeySignerPrivateKey: useLocalStorage<string>(
      "cashu.ndk.privateKeySignerPrivateKey",
      ""
    ),
    seedSignerPrivateKey: useLocalStorage<string>(
      "cashu.ndk.seedSignerPrivateKey",
      ""
    ),
    seedSignerPublicKey: useLocalStorage<string>(
      "cashu.ndk.seedSignerPublicKey",
      ""
    ),
    seedSigner: {} as NDKPrivateKeySigner,
    seedSignerPrivateKeyNsec: "",
    privateKeySigner: {} as NDKPrivateKeySigner,
    signer: {} as NDKSigner,
    mintRecommendations: useLocalStorage<MintRecommendation[]>(
      "cashu.ndk.mintRecommendations",
      []
    ),
    initialized: false,
    lastEventTimestamp: useLocalStorage<number>(
      "cashu.ndk.lastEventTimestamp",
      0
    ),
    nip17EventIdsWeHaveSeen: useLocalStorage<NostrEventLog[]>(
      "cashu.ndk.nip17EventIdsWeHaveSeen",
      []
    ),
  }),
  getters: {
    seedSignerPrivateKeyNsec: (state) => {
      const sk = hexToBytes(state.seedSignerPrivateKey);
      return nip19.nsecEncode(sk);
    },
    nprofile: (state) => {
      const profile: ProfilePointer = {
        pubkey: state.pubkey,
        relays: state.relays,
      };
      return nip19.nprofileEncode(profile);
    },
    seedSignerNprofile: (state) => {
      const profile: ProfilePointer = {
        pubkey: state.seedSignerPublicKey,
        relays: state.relays,
      };
      return nip19.nprofileEncode(profile);
    },
  },
  actions: {
    initNdkReadOnly: function () {
      this.ndk = new NDK({ explicitRelayUrls: this.relays });
      this.ndk.connect();
      this.connected = true;
    },
    initSignerIfNotSet: async function () {
      if (!this.initialized) {
        await this.initSigner();
      }
    },
    initSigner: async function () {
      if (this.signerType === SignerType.NIP07) {
        await this.initNip07Signer();
      } else if (this.signerType === SignerType.NIP46) {
        await this.initNip46Signer();
      } else if (this.signerType === SignerType.PRIVATEKEY) {
        await this.initPrivateKeySigner();
      } else {
        await this.initWalletSeedPrivateKeySigner();
      }
      this.initialized = true;
    },
    setSigner: function (signer: NDKSigner) {
      this.signer = signer;
      this.ndk = new NDK({ signer: signer, explicitRelayUrls: this.relays });
    },
    signDummyEvent: async function (): Promise<NDKEvent> {
      const ndkEvent = new NDKEvent();
      ndkEvent.kind = 1;
      ndkEvent.content = "Hello, world!";
      const sig = await ndkEvent.sign(this.signer);
      console.log(`nostr signature: ${sig})`);
      const eventString = JSON.stringify(ndkEvent.rawEvent());
      console.log(`nostr event: ${eventString}`);
      return ndkEvent;
    },
    setPubkey: function (pubkey: string) {
      console.log("Setting pubkey to", pubkey);
      this.pubkey = pubkey;
    },
    checkNip07Signer: async function (): Promise<boolean> {
      const signer = new NDKNip07Signer();
      try {
        await signer.user();
        return true;
      } catch (e) {
        return false;
      }
    },
    initNip07Signer: async function () {
      const signer = new NDKNip07Signer();
      const user = await signer.blockUntilReady();
      this.signerType = SignerType.NIP07;
      this.setSigner(signer);
      this.setPubkey(user.pubkey);
    },
    initNip46Signer: async function (nip46Token?: string) {
      const ndk = new NDK({ explicitRelayUrls: this.relays });
      if (!nip46Token && !this.nip46Token.length) {
        nip46Token = (await prompt(
          "Enter your NIP-46 connection string"
        )) as string;
        if (!nip46Token) {
          return;
        }
        this.nip46Token = nip46Token;
      } else {
        if (nip46Token) {
          this.nip46Token = nip46Token;
        }
      }
      const signer = new NDKNip46Signer(ndk, this.nip46Token);
      this.signerType = SignerType.NIP46;
      this.setSigner(signer);
      // If the backend sends an auth_url event, open that URL as a popup so the user can authorize the app
      signer.on("authUrl", (url) => {
        window.open(url, "auth", "width=600,height=600");
      });
      // wait until the signer is ready
      const loggedinUser = await signer.blockUntilReady();
      alert("You are now logged in as " + loggedinUser.npub);
      this.setPubkey(loggedinUser.pubkey);
    },
    resetNip46Signer: async function () {
      this.nip46Token = "";
      await this.initWalletSeedPrivateKeySigner();
    },
    initPrivateKeySigner: async function (nsec?: string) {
      let privateKeyBytes: Uint8Array;
      if (!nsec && !this.privateKeySignerPrivateKey.length) {
        nsec = (await prompt("Enter your nsec")) as string;
        if (!nsec) {
          return;
        }
        privateKeyBytes = nip19.decode(nsec).data as Uint8Array;
      } else {
        if (nsec) {
          privateKeyBytes = nip19.decode(nsec).data as Uint8Array;
        } else {
          privateKeyBytes = hexToBytes(this.privateKeySignerPrivateKey);
        }
      }
      this.privateKeySigner = new NDKPrivateKeySigner(
        this.privateKeySignerPrivateKey
      );
      this.privateKeySignerPrivateKey = bytesToHex(privateKeyBytes);
      this.signerType = SignerType.PRIVATEKEY;
      this.setSigner(this.privateKeySigner);
      const publicKeyHex = getPublicKey(privateKeyBytes);
      this.setPubkey(publicKeyHex);
    },
    resetPrivateKeySigner: async function () {
      this.privateKeySignerPrivateKey = "";
      await this.initWalletSeedPrivateKeySigner();
    },
    walletSeedGenerateKeyPair: async function () {
      const walletStore = useWalletStore();
      const sk = walletStore.seed.slice(0, 32);
      const walletPublicKeyHex = getPublicKey(sk); // `pk` is a hex string
      const walletPrivateKeyHex = bytesToHex(sk);
      this.seedSignerPrivateKey = walletPrivateKeyHex;
      this.seedSignerPublicKey = walletPublicKeyHex;
      this.seedSigner = new NDKPrivateKeySigner(this.seedSignerPrivateKey);
    },
    initWalletSeedPrivateKeySigner: async function () {
      await this.walletSeedGenerateKeyPair();
      // Use the seed-based signer as the main private key signer
      this.privateKeySigner = this.seedSigner;
      this.signerType = SignerType.SEED;
      this.setSigner(this.privateKeySigner);
      this.setPubkey(this.seedSignerPublicKey);
    },
    fetchEventsFromUser: async function () {
      const filter: NDKFilter = { kinds: [1], authors: [this.pubkey] };
      return await this.ndk.fetchEvents(filter);
    },
    fetchMints: async function () {
      const filter: NDKFilter = { kinds: [38000 as NDKKind], limit: 2000 };
      const events = await this.ndk.fetchEvents(filter);
      let mintUrls: string[] = [];
      events.forEach((event) => {
        if (event.tagValue("k") == "38172" && event.tagValue("u")) {
          const mintUrl = event.tagValue("u");
          if (
            typeof mintUrl === "string" &&
            mintUrl.length > 0 &&
            mintUrl.startsWith("https://")
          ) {
            mintUrls.push(mintUrl);
          }
        }
      });
      // Count the number of times each mint URL appears
      const mintUrlsSet = new Set(mintUrls);
      const mintUrlsArray = Array.from(mintUrlsSet);
      const mintUrlsCounted = mintUrlsArray.map((url) => {
        return { url: url, count: mintUrls.filter((u) => u === url).length };
      });
      mintUrlsCounted.sort((a, b) => b.count - a.count);
      this.mintRecommendations = mintUrlsCounted;
      return mintUrlsCounted;
    },
    sendNip04DirectMessage: async function (
      recipient: string,
      message: string
    ) {
      // Decode npub to hex if necessary
      let recipientPubkeyHex = recipient;
      if (recipient.startsWith('npub1')) {
        try {
          const decoded = nip19.decode(recipient);
          if (decoded.type === 'npub') {
            recipientPubkeyHex = decoded.data as string;
            console.log(`📤 Decoded npub to hex: ${recipientPubkeyHex.substring(0, 16)}...`);
          }
        } catch (e) {
          console.error('❌ Failed to decode npub:', e);
          notifyError(`Invalid npub format: ${e}`);
          return;
        }
      }

      console.log(`📤 Sending plaintext Cashu token to: ${recipientPubkeyHex.substring(0, 16)}...`);
      console.log(`📤 Message length: ${message.length} chars`);

      // Use wallet seed signer for consistency
      await this.walletSeedGenerateKeyPair();

      const ndk = new NDK({
        explicitRelayUrls: this.relays,
        signer: new NDKPrivateKeySigner(this.seedSignerPrivateKey),
      });

      await ndk.connect();

      const event = new NDKEvent(ndk);
      event.kind = 4; // DM kind, but sending plaintext (Cashu tokens are bearer tokens)
      event.content = message; // No encryption - token is already a bearer token
      event.tags = [["p", recipientPubkeyHex]];

      console.log(`📤 Signing event with our seedSigner: ${this.seedSignerPublicKey.substring(0, 16)}...`);
      await event.sign();

      console.log(`📤 Publishing to relays:`, this.relays);
      try {
        await event.publish();
        console.log(`✅ Event published successfully`);
        notifySuccess("Sent via Nostr");
      } catch (e) {
        console.error('❌ Failed to publish event:', e);
        notifyError(`Could not publish: ${e}`);
      }
    },
    subscribeToNip04DirectMessages: async function () {
      await this.walletSeedGenerateKeyPair();
      await this.initNdkReadOnly();
      let nip04DirectMessageEvents: Set<NDKEvent> = new Set();
      const fetchEventsPromise = new Promise<Set<NDKEvent>>((resolve) => {
        // Subscribe from 24 hours ago to catch recent messages
        const oneDayAgo = Math.floor(Date.now() / 1000) - (24 * 60 * 60);
        const subscribeFrom = this.lastEventTimestamp || oneDayAgo;

        console.log(
          `### Subscribing to NIP-04 direct messages to ${this.seedSignerPublicKey} since ${subscribeFrom}`
        );
        console.log(`🔔 Will receive messages from the last 24 hours`);

        this.ndk.connect();
        const sub = this.ndk.subscribe(
          {
            kinds: [4], // Kind 4 DMs (we're sending plaintext now)
            "#p": [this.seedSignerPublicKey],
            since: subscribeFrom,
          } as NDKFilter,
          { closeOnEose: false, groupable: false }
        );
        sub.on("event", (event: NDKEvent) => {
          console.log("📨 Nostr DM received from relay (kind 4)");
          console.log("📨 Sender pubkey:", event.pubkey.substring(0, 16) + "...");
          console.log("📨 Recipient (us):", this.seedSignerPublicKey.substring(0, 16) + "...");
          console.log("📨 Content (plaintext Cashu):", event.content.substring(0, 50) + "...");

          // No decryption needed - Cashu tokens are bearer tokens
          // We send them as plaintext for simplicity and compatibility
          nip04DirectMessageEvents.add(event);
          this.lastEventTimestamp = Math.floor(Date.now() / 1000);
          this.parseMessageForEcash(event.content);
        });
      });
      try {
        nip04DirectMessageEvents = await fetchEventsPromise;
      } catch (error) {
        console.error("Error fetching contact events:", error);
      }
    },
    sendNip17DirectMessageToNprofile: async function (
      nprofile: string,
      message: string
    ) {
      const result = nip19.decode(nprofile);
      const pubkey: string = (result.data as ProfilePointer).pubkey;
      const relays: string[] | undefined = (result.data as ProfilePointer)
        .relays;
      this.sendNip17DirectMessage(pubkey, message, relays);
    },
    randomTimeUpTo2DaysInThePast: function () {
      return Math.floor(Date.now() / 1000) - Math.floor(Math.random() * 172800);
    },
    sendNip17DirectMessage: async function (
      recipient: string,
      message: string,
      relays?: string[]
    ) {
      await this.walletSeedGenerateKeyPair();
      const randomPrivateKey = generateSecretKey();
      const randomPublicKey = getPublicKey(randomPrivateKey);

      const dmEvent = new NDKEvent();
      dmEvent.kind = 14;
      dmEvent.content = message;
      dmEvent.tags = [["p", recipient]];
      dmEvent.created_at = Math.floor(Date.now() / 1000);
      dmEvent.pubkey = this.seedSignerPublicKey;
      dmEvent.id = dmEvent.getEventHash();
      const dmEventString = JSON.stringify(await dmEvent.toNostrEvent());

      const seedNdk = new NDK({
        signer: this.seedSigner,
        explicitRelayUrls: this.relays,
      });
      const sealEvent = new NDKEvent(seedNdk);
      sealEvent.kind = 13;
      sealEvent.content = nip44.v2.encrypt(
        dmEventString,
        nip44.v2.utils.getConversationKey(this.seedSignerPrivateKey, recipient)
      );
      sealEvent.created_at = this.randomTimeUpTo2DaysInThePast();
      sealEvent.pubkey = this.seedSignerPublicKey;
      sealEvent.id = sealEvent.getEventHash();
      sealEvent.sig = await sealEvent.sign();
      const sealEventString = JSON.stringify(await sealEvent.toNostrEvent());

      const randomNdk = new NDK({
        explicitRelayUrls: relays ?? this.relays,
        signer: new NDKPrivateKeySigner(bytesToHex(randomPrivateKey)),
      });
      const wrapEvent = new NDKEvent(randomNdk);
      wrapEvent.kind = 1059;
      wrapEvent.tags = [["p", recipient]];
      wrapEvent.content = nip44.v2.encrypt(
        sealEventString,
        nip44.v2.utils.getConversationKey(
          bytesToHex(randomPrivateKey),
          recipient
        )
      );
      wrapEvent.created_at = this.randomTimeUpTo2DaysInThePast();
      wrapEvent.pubkey = randomPublicKey;
      wrapEvent.id = wrapEvent.getEventHash();
      wrapEvent.sig = await wrapEvent.sign();

      try {
        randomNdk.connect();
        await wrapEvent.publish();
      } catch (e) {
        console.error(e);
        notifyError("Could not publish NIP-17 event");
      }
    },
    subscribeToNip17DirectMessages: async function () {
      await this.walletSeedGenerateKeyPair();
      await this.initNdkReadOnly();
      let nip17DirectMessageEvents: Set<NDKEvent> = new Set();
      const fetchEventsPromise = new Promise<Set<NDKEvent>>((resolve) => {
        if (!this.lastEventTimestamp) {
          this.lastEventTimestamp = Math.floor(Date.now() / 1000);
        }
        const since = this.lastEventTimestamp - 172800; // last 2 days
        console.log(
          `### Subscribing to NIP-17 direct messages to ${this.seedSignerPublicKey} since ${since}`
        );
        this.ndk.connect();
        const sub = this.ndk.subscribe(
          {
            kinds: [1059 as NDKKind],
            "#p": [this.seedSignerPublicKey],
            since: since,
          } as NDKFilter,
          { closeOnEose: false, groupable: false }
        );

        sub.on("event", (wrapEvent: NDKEvent) => {
          const eventLog = {
            id: wrapEvent.id,
            created_at: wrapEvent.created_at,
          } as NostrEventLog;
          if (this.nip17EventIdsWeHaveSeen.find((e) => e.id === wrapEvent.id)) {
            // console.log(`### Already seen NIP-17 event ${wrapEvent.id} (time: ${wrapEvent.created_at})`);
            return;
          } else {
            console.log(`### New event ${wrapEvent.id}`);
            this.nip17EventIdsWeHaveSeen.push(eventLog);
            // remove all events older than 10 days to keep the list small
            const fourDaysAgo =
              Math.floor(Date.now() / 1000) - 10 * 24 * 60 * 60;
            this.nip17EventIdsWeHaveSeen = this.nip17EventIdsWeHaveSeen.filter(
              (e) => e.created_at > fourDaysAgo
            );
          }
          let dmEvent: NDKEvent;
          let content: string;
          try {
            const wappedContent = nip44.v2.decrypt(
              wrapEvent.content,
              nip44.v2.utils.getConversationKey(
                this.seedSignerPrivateKey,
                wrapEvent.pubkey
              )
            );
            const sealEvent = JSON.parse(wappedContent) as NostrEvent;
            const dmEventString = nip44.v2.decrypt(
              sealEvent.content,
              nip44.v2.utils.getConversationKey(
                this.seedSignerPrivateKey,
                sealEvent.pubkey
              )
            );
            dmEvent = JSON.parse(dmEventString) as NDKEvent;
            content = dmEvent.content;
            console.log("### NIP-17 DM from", dmEvent.pubkey);
            console.log("Content:", content);
          } catch (e) {
            console.error(e);
            return;
          }
          nip17DirectMessageEvents.add(dmEvent);
          this.lastEventTimestamp = Math.floor(Date.now() / 1000);
          this.parseMessageForEcash(content);
        });
      });
      try {
        nip17DirectMessageEvents = await fetchEventsPromise;
      } catch (error) {
        console.error("Error fetching contact events:", error);
      }
    },
    parseMessageForEcash: async function (message: string) {
      console.log('🔍 parseMessageForEcash called with message length:', message.length);
      console.log('🔍 Message preview:', message.substring(0, 50) + '...');

      // first check if the message can be converted to a json and then to a PaymentRequestPayload
      try {
        const payload = JSON.parse(message) as PaymentRequestPayload;
        console.log('📦 Parsed as JSON payment request');
        if (payload) {
          const receiveStore = useReceiveTokensStore();
          const prStore = usePRStore();
          const sendTokensStore = useSendTokensStore();
          const tokensStore = useTokensStore();
          const proofs = payload.proofs;
          const mint = payload.mint;
          const unit = payload.unit;
          const token = {
            proofs: proofs,
            mint: mint,
            unit: unit,
          } as Token;

          const tokenStr = getEncodedTokenV4(token);

          const tokenInHistory = tokensStore.tokenAlreadyInHistory(tokenStr);
          if (tokenInHistory && tokenInHistory.amount > 0) {
            console.log("### incoming token already in history");
            return;
          }
          await this.addPendingTokenToHistory(tokenStr, false);
          receiveStore.receiveData.tokensBase64 = tokenStr;
          sendTokensStore.showSendTokens = false;
          if (prStore.receivePaymentRequestsAutomatically) {
            const success = await receiveStore.receiveIfDecodes();
            if (success) {
              prStore.showPRDialog = false;
            } else {
              notifyWarning("Could not receive incoming payment");
            }
          } else {
            prStore.showPRDialog = false;
            receiveStore.showReceiveTokens = true;
          }
          return;
        }
      } catch (e) {
        console.log("📦 Not a JSON payment request, trying Cashu token parsing...");
      }

      console.log("🔍 Parsing message for Cashu tokens");
      const receiveStore = useReceiveTokensStore();
      const tokensStore = useTokensStore();
      const words = message.split(" ");
      const tokens = words.filter((word) => {
        return word.startsWith("cashuA") || word.startsWith("cashuB");
      });
      console.log(`🔍 Found ${tokens.length} Cashu token(s) in message`);

      for (const tokenStr of tokens) {
        console.log(`💰 Processing Cashu token: ${tokenStr.substring(0, 30)}...`);

        // Check if already in history AND claimed (amount < 0 means claimed)
        const tokenInHistory = tokensStore.tokenAlreadyInHistory(tokenStr);
        if (tokenInHistory) {
          if (tokenInHistory.amount < 0) {
            console.log("ℹ️ Token already claimed, skipping");
            continue;
          } else {
            console.log("ℹ️ Token in history but not claimed yet, will auto-claim");
          }
        } else {
          // Add to history first if not already there
          await this.addPendingTokenToHistory(tokenStr, false);
        }

        // Auto-claim for Nostr messages (we have internet connection)
        console.log('💎 Auto-claiming Cashu token from Nostr...');
        receiveStore.receiveData.tokensBase64 = tokenStr;

        try {
          const success = await receiveStore.receiveIfDecodes();
          if (success) {
            console.log('✅ Token claimed successfully!');
            notifySuccess('💰 Received ecash via Nostr!');
          } else {
            console.warn('⚠️ Auto-claim failed, showing receive dialog');
            receiveStore.showReceiveTokens = true;
          }
        } catch (error) {
          console.error('❌ Auto-claim error:', error);
          receiveStore.showReceiveTokens = true;
        }
      }
    },
    addPendingTokenToHistory: function (tokenStr: string, verbose = true) {
      console.log('💾 addPendingTokenToHistory called');
      const receiveStore = useReceiveTokensStore();
      const tokensStore = useTokensStore();
      if (tokensStore.tokenAlreadyInHistory(tokenStr)) {
        console.log('ℹ️ Token already in history, skipping');
        notifySuccess("Ecash already in history");
        receiveStore.showReceiveTokens = false;
        return;
      }
      console.log('🔓 Decoding Cashu token...');
      const decodedToken = token.decode(tokenStr);
      if (decodedToken == undefined) {
        console.error('❌ Failed to decode token');
        throw Error("could not decode token");
      }
      // get amount from decodedToken.token.proofs[..].amount
      const amount = token
        .getProofs(decodedToken)
        .reduce((sum, el) => (sum += el.amount), 0);

      console.log(`💰 Adding ${amount} ${token.getUnit(decodedToken)} to pending tokens`);

      tokensStore.addPendingToken({
        amount: amount,
        token: tokenStr,
        mint: token.getMint(decodedToken),
        unit: token.getUnit(decodedToken),
      });
      console.log('✅ Token added to pending history');
      receiveStore.showReceiveTokens = false;
      // show success notification
      if (verbose) {
        notifySuccess("Ecash added to history.");
      }
    },

    /**
     * Send ecash token via Nostr DM (for mutual favorites fallback)
     * Implements BitChat's Nostr fallback pattern
     */
    async sendTokenViaNostr(token: string, recipientNpub: string, senderNickname: string = 'Bitpoints User') {
      try {
        if (!this.ndk || !this.connected) {
          throw new Error('Nostr not connected');
        }

        // Create token notification content
        const content = JSON.stringify({
          type: 'BITPOINTS_TOKEN',
          token,
          timestamp: Date.now(),
          senderNpub: this.npub,
          senderNickname,
        });

        // Encrypt and send as DM (NIP-04)
        const recipientHex = nip19.decode(recipientNpub).data as string;
        const encrypted = await nip04.encrypt(this.privateKey, recipientHex, content);

        // Create DM event (kind 4)
        const dmEvent = new NDKEvent(this.ndk);
        dmEvent.kind = 4; // Encrypted Direct Message
        dmEvent.content = encrypted;
        dmEvent.tags = [['p', recipientHex]];

        await dmEvent.publish();

        console.log(`📨 Sent token via Nostr to ${recipientNpub.substring(0, 16)}...`);
      } catch (error) {
        console.error('Failed to send token via Nostr:', error);
        throw error;
      }
    },

    /**
     * Send encrypted DM via Nostr
     * Generic method for sending any encrypted content
     */
    async sendEncryptedDM(content: string, recipientNpub: string) {
      if (!this.ndk || !this.connected) {
        throw new Error('Nostr not connected');
      }

      const recipientHex = nip19.decode(recipientNpub).data as string;
      const encrypted = await nip04.encrypt(this.privateKey, recipientHex, content);

      const dmEvent = new NDKEvent(this.ndk);
      dmEvent.kind = 4;
      dmEvent.content = encrypted;
      dmEvent.tags = [['p', recipientHex]];

      await dmEvent.publish();
    },

    /**
     * Listen for incoming Nostr token notifications
     * Auto-redeems tokens sent via Nostr fallback
     */
    async setupTokenNotificationListener() {
      if (!this.ndk || !this.connected || !this.pubkey) return;

      const filter: NDKFilter = {
        kinds: [4], // Encrypted DMs
        '#p': [this.pubkey],
        since: Math.floor(Date.now() / 1000) - 86400, // Last 24 hours
      };

      const sub = this.ndk.subscribe(filter, { closeOnEose: false });

      sub.on('event', async (event: NDKEvent) => {
        try {
          // Decrypt DM
          const senderPubkey = event.pubkey;
          const decrypted = await nip04.decrypt(
            this.privateKey,
            senderPubkey,
            event.content
          );

          const data = JSON.parse(decrypted);

          // Handle Bitpoints token notification
          if (data.type === 'BITPOINTS_TOKEN') {
            console.log('📨 Received token via Nostr from', data.senderNpub?.substring(0, 16));

            // Auto-redeem the token
            const receiveStore = useReceiveTokensStore();
            const walletStore = useWalletStore();

            receiveStore.receiveData.tokensBase64 = data.token;
            await walletStore.redeem();

            notifySuccess(
              `Received tokens via Nostr from ${data.senderNickname || 'unknown'}!`
            );
          }
        } catch (error) {
          console.error('Failed to process Nostr DM:', error);
        }
      });

      console.log('👂 Listening for Nostr token notifications');
    },
  },
});
