import { defineStore } from "pinia";
import {
  DEFAULT_KEY_SERVER_URL,
  KeyServerFetchPayload,
  KeyServerInfo,
  KeyServerStorePayload,
  RecoverbullKeyServerClient,
  RecoverbullKeyServerError,
} from "src/services/recoverbullKeyServer";

export interface KeyServerRateLimit {
  requestedAt?: string;
  cooldownMinutes?: number;
  attempts?: number;
}

export interface RecoverbullKeyServerState {
  baseUrl: string;
  info: KeyServerInfo | null;
  pending: boolean;
  lastError: string | null;
  rateLimit: KeyServerRateLimit | null;
}

export const useRecoverbullKeyServerStore = defineStore("recoverbullKeyServer", {
  state: (): RecoverbullKeyServerState => ({
    baseUrl: DEFAULT_KEY_SERVER_URL,
    info: null,
    pending: false,
    lastError: null,
    rateLimit: null,
  }),

  getters: {
    isConfigured: (state) => state.baseUrl.length > 0,
    isCoolingDown: (state) => {
      if (!state.rateLimit?.cooldownMinutes || !state.rateLimit.requestedAt) {
        return false;
      }
      const requested = Date.parse(state.rateLimit.requestedAt);
      if (Number.isNaN(requested)) {
        return false;
      }
      const expiresAt = requested + state.rateLimit.cooldownMinutes * 60 * 1000;
      return Date.now() < expiresAt;
    },
    cooldownRemainingMs(): number | null {
      if (!this.rateLimit?.cooldownMinutes || !this.rateLimit.requestedAt) {
        return null;
      }
      const requested = Date.parse(this.rateLimit.requestedAt);
      if (Number.isNaN(requested)) {
        return null;
      }
      const expiresAt = requested + this.rateLimit.cooldownMinutes * 60 * 1000;
      return Math.max(0, expiresAt - Date.now());
    },
  },

  actions: {
    setBaseUrl(url: string) {
      const sanitized = url.trim();
      this.baseUrl = sanitized.length > 0 ? sanitized : DEFAULT_KEY_SERVER_URL;
    },

    clearError() {
      this.lastError = null;
      this.rateLimit = null;
    },

    async fetchInfo(): Promise<KeyServerInfo> {
      this.pending = true;
      try {
        const client = this.createClient();
        const info = await client.getInfo();
        this.info = info;
        this.lastError = null;
        return info;
      } catch (error) {
        this.handleError(error);
        throw error;
      } finally {
        this.pending = false;
      }
    },

    async storeBackupKey(payload: KeyServerStorePayload): Promise<void> {
      this.pending = true;
      try {
        const client = this.createClient();
        await client.storeBackupKey(payload);
        this.lastError = null;
        this.rateLimit = null;
      } catch (error) {
        this.handleError(error);
        throw error;
      } finally {
        this.pending = false;
      }
    },

    async fetchBackupKey(
      payload: KeyServerFetchPayload
    ): Promise<Uint8Array> {
      this.pending = true;
      try {
        const client = this.createClient();
        const backupKey = await client.fetchBackupKey(payload);
        this.lastError = null;
        this.rateLimit = null;
        return backupKey;
      } catch (error) {
        this.handleError(error);
        throw error;
      } finally {
        this.pending = false;
      }
    },

    async trashBackupKey(
      payload: KeyServerFetchPayload
    ): Promise<Uint8Array> {
      this.pending = true;
      try {
        const client = this.createClient();
        const backupKey = await client.trashBackupKey(payload);
        this.lastError = null;
        this.rateLimit = null;
        return backupKey;
      } catch (error) {
        this.handleError(error);
        throw error;
      } finally {
        this.pending = false;
      }
    },

    createClient(): RecoverbullKeyServerClient {
      return new RecoverbullKeyServerClient({
        baseUrl: this.baseUrl,
      });
    },

    handleError(error: unknown) {
      const keyError =
        error instanceof RecoverbullKeyServerError
          ? error
          : error instanceof Error
          ? new RecoverbullKeyServerError(error.message)
          : new RecoverbullKeyServerError("Unknown key server error");

      this.lastError = keyError.message;
      this.rateLimit =
        keyError.cooldownMinutes || keyError.requestedAt || keyError.attempts
          ? {
              requestedAt: keyError.requestedAt,
              cooldownMinutes: keyError.cooldownMinutes,
              attempts: keyError.attempts,
            }
          : null;
    },
  },
});


