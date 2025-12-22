import { defineStore } from "pinia";
import { useNostrStore } from "./nostr";
import { useBluetoothStore } from "./bluetooth";
import { useFavoritesStore } from "./favorites";
import { notifySuccess, notifyError, notifyWarning } from "../js/notify";
import { nip19 } from "nostr-tools";

/// Verification modes for QR codes
export enum QRVerificationMode {
  CONTACT_EXCHANGE = "contact_exchange",
  CRYPTOGRAPHIC_VERIFICATION = "cryptographic_verification",
}

/// QR payload for contact exchange (backward compatible)
export interface ContactQR {
  type: "contact";
  npub: string;
  nickname: string;
}

/// QR payload for cryptographic verification (Bitchat-style)
export interface VerificationQR {
  v: number;
  noiseKeyHex: string;
  signKeyHex: string;
  npub: string;
  nickname: string;
  ts: number;
  nonceB64: string;
  sigHex: string;
}

export type QRPayload = ContactQR | VerificationQR;

export const useVerificationStore = defineStore("verification", {
  state: () => ({
    verifiedFingerprints: new Set<string>(),
  }),

  actions: {
    /// Verify a BitChat verification QR code
    async verifyBitChatQR(verificationData: VerificationQR): Promise<boolean> {
      try {
        // Check timestamp (5 minute expiry like BitChat)
        const now = Math.floor(Date.now() / 1000);
        const qrTime = verificationData.ts;
        const ageSeconds = now - qrTime;

        if (ageSeconds > 300 || ageSeconds < -60) {
          // 5 minutes expiry, allow 1 minute clock skew
          console.warn("BitChat QR code expired or from future:", {
            ageSeconds,
            qrTime,
            now,
          });
          return false;
        }

        // TODO: Verify signature if needed
        // For now, we trust the QR code if timestamp is valid
        console.log("✅ BitChat QR code verified (timestamp check passed)");
        return true;
      } catch (error) {
        console.error("❌ BitChat QR verification failed:", error);
        return false;
      }
    },

    /// Mark a fingerprint as verified
    markFingerprintVerified(fingerprint: string) {
      this.verifiedFingerprints.add(fingerprint);
      console.log("✅ Fingerprint marked as verified:", fingerprint);
    },

    /// Check if a fingerprint is verified
    isFingerprintVerified(fingerprint: string): boolean {
      return this.verifiedFingerprints.has(fingerprint);
    },

    /// Generate a QR string for contact sharing/verification
    async generateQRString(
      mode: QRVerificationMode = QRVerificationMode.CONTACT_EXCHANGE
    ): Promise<string | null> {
      const nostrStore = useNostrStore();

      if (mode === QRVerificationMode.CONTACT_EXCHANGE) {
        // Simple contact exchange (backward compatible)
        try {
          await nostrStore.walletSeedGenerateKeyPair();
          const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
          if (!hexPubkey) {
            notifyError(
              "Nostr key not available. Please configure Nostr first."
            );
            return null;
          }

          const npub = hexPubkey.startsWith("npub")
            ? hexPubkey
            : nip19.npubEncode(hexPubkey);

          const contactData: ContactQR = {
            type: "contact",
            npub: npub,
            nickname: bluetoothStore.nickname,
          };

          return JSON.stringify(contactData);
        } catch (error) {
          console.error("Failed to generate contact QR:", error);
          notifyError("Failed to generate QR code");
          return null;
        }
      } else {
        // Cryptographic verification (Bitchat-style)
        return this.generateVerificationQRString();
      }
    },

    /// Generate a cryptographically signed QR string for verification
    async generateVerificationQRString(): Promise<string | null> {
      const nostrStore = useNostrStore();
      const bluetoothStore = useBluetoothStore();

      try {
        // Generate keys if needed
        if (!nostrStore.seedSignerPublicKey) {
          await nostrStore.walletSeedGenerateKeyPair();
        }

        const hexPubkey = nostrStore.seedSignerPublicKey || nostrStore.pubkey;
        if (!hexPubkey) {
          notifyError("Nostr key not available. Please configure Nostr first.");
          return null;
        }

        // For now, use nostr keys as placeholders for noise/signing keys
        // In a full implementation, these would be actual Noise protocol keys
        const noiseKey = hexPubkey;
        const signKey = hexPubkey;

        const npub = hexPubkey.startsWith("npub")
          ? hexPubkey
          : nip19.npubEncode(hexPubkey);

        const ts = Math.floor(Date.now() / 1000);
        const nonce = crypto.getRandomValues(new Uint8Array(16));
        const nonceB64 = btoa(String.fromCharCode(...nonce))
          .replace(/\+/g, "-")
          .replace(/\//g, "_")
          .replace(/=/g, "");

        const payload: VerificationQR = {
          v: 1,
          noiseKeyHex: noiseKey,
          signKeyHex: signKey,
          npub: npub,
          nickname: bluetoothStore.nickname,
          ts: ts,
          nonceB64: nonceB64,
          sigHex: "", // TODO: Add actual signature
        };

        // For now, return unsigned payload
        // In full implementation, this would be signed like Bitchat
        return JSON.stringify(payload);
      } catch (error) {
        console.error("Failed to generate verification QR:", error);
        notifyError("Failed to generate verification QR code");
        return null;
      }
    },

    /// Parse and validate a scanned QR code
    async processScannedQR(
      qrString: string
    ): Promise<{ success: boolean; mode: QRVerificationMode; contact?: any }> {
      try {
        // Try to parse as JSON
        const data = JSON.parse(qrString);

        if (data.type === "contact") {
          // Simple contact exchange
          return this.processContactQR(data as ContactQR);
        } else if (data.v && data.noiseKeyHex) {
          // Cryptographic verification
          return this.processVerificationQR(data as VerificationQR);
        } else {
          throw new Error("Unknown QR format");
        }
      } catch (error) {
        console.error("Failed to parse QR code:", error);
        return { success: false, mode: QRVerificationMode.CONTACT_EXCHANGE };
      }
    },

    /// Process a simple contact QR code
    async processContactQR(
      data: ContactQR
    ): Promise<{ success: boolean; mode: QRVerificationMode; contact?: any }> {
      // Validate required fields
      if (!data.npub || !data.nickname || data.nickname.trim() === "") {
        notifyError("Invalid QR code. Missing required fields.");
        return { success: false, mode: QRVerificationMode.CONTACT_EXCHANGE };
      }

      // Add as contact (existing logic from ContactsDialog)
      const favoritesStore = useFavoritesStore();
      const scannedNpub = data.npub;
      const scannedNickname = data.nickname.trim();

      // Check if already a favorite
      const existingFavorites = Object.values(favoritesStore.favorites);
      const existingFavorite = existingFavorites.find(
        (fav) => fav.peerNostrNpub === scannedNpub
      );

      if (existingFavorite) {
        if (existingFavorite.isFavorite && existingFavorite.theyFavoritedUs) {
          notifySuccess(`${scannedNickname} is already your mutual favorite!`);
        } else {
          favoritesStore.updatePeerFavoritedUs(
            existingFavorite.peerNoisePublicKey,
            true
          );
          notifySuccess(
            `💕 You and ${scannedNickname} are now mutual favorites!`
          );
        }
        return {
          success: true,
          mode: QRVerificationMode.CONTACT_EXCHANGE,
          contact: existingFavorite,
        };
      }

      // Generate a peerID from npub
      const npubHash = await crypto.subtle.digest(
        "SHA-256",
        new TextEncoder().encode(scannedNpub)
      );
      const hashArray = Array.from(new Uint8Array(npubHash));
      const peerID = hashArray
        .slice(0, 16)
        .map((b) => b.toString(16).padStart(2, "0"))
        .join("");

      // Add as favorite and mark as mutual
      favoritesStore.addFavorite(peerID, scannedNickname, scannedNpub);
      favoritesStore.updatePeerFavoritedUs(peerID, true);

      notifySuccess(
        `💕 Added ${scannedNickname} as mutual favorite! You can now send messages via Nostr.`
      );

      return {
        success: true,
        mode: QRVerificationMode.CONTACT_EXCHANGE,
        contact: { peerID, nickname: scannedNickname, npub: scannedNpub },
      };
    },

    /// Process a cryptographic verification QR code
    async processVerificationQR(
      data: VerificationQR
    ): Promise<{ success: boolean; mode: QRVerificationMode; contact?: any }> {
      // TODO: Implement cryptographic verification logic
      // For now, fall back to contact exchange
      notifyWarning(
        "Cryptographic verification not yet implemented. Treating as contact exchange."
      );
      return this.processContactQR({
        type: "contact",
        npub: data.npub,
        nickname: data.nickname,
      });
    },

    /// Mark a contact as verified
    markVerified(fingerprint: string) {
      this.verifiedFingerprints.add(fingerprint);
    },

    /// Check if a contact is verified
    isVerified(fingerprint: string): boolean {
      return this.verifiedFingerprints.has(fingerprint);
    },
  },
});
