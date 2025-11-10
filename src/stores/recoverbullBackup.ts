import { defineStore } from "pinia";
import {
  bytesToHex,
  createRecoverbullBackup,
  hexToBytes,
  parseBullBackup,
  restoreRecoverbullBackup,
} from "src/utils/recoverbullVault";
import { useRecoverbullKeyServerStore } from "src/stores/recoverbullKeyServer";

export interface RecoverbullBackupSummary {
  identifierHex: string;
  derivationPath: string;
  createdAt: number;
  fileName: string;
  backupJson: string;
}

export interface RecoverbullRestoreSummary {
  identifierHex: string;
  restoredAt: number;
}

export interface RecoverbullBackupState {
  backupInProgress: boolean;
  restoreInProgress: boolean;
  lastError: string | null;
  lastBackup: RecoverbullBackupSummary | null;
  lastRestore: RecoverbullRestoreSummary | null;
  lastRestoredMnemonic: string[] | null;
}

export interface CreateBackupPayload {
  mnemonic: string[];
  password: string;
}

export interface RestoreBackupPayload {
  backupJson: string;
  password: string;
}

export const useRecoverbullBackupStore = defineStore("recoverbullBackup", {
  state: (): RecoverbullBackupState => ({
    backupInProgress: false,
    restoreInProgress: false,
    lastError: null,
    lastBackup: null,
    lastRestore: null,
    lastRestoredMnemonic: null,
  }),

  getters: {
    hasBackup: (state) => state.lastBackup !== null,
    lastBackupFileName: (state) => state.lastBackup?.fileName ?? null,
  },

  actions: {
    reset() {
      this.lastError = null;
      this.lastBackup = null;
      this.lastRestore = null;
      this.lastRestoredMnemonic = null;
    },

    setError(message: string | null) {
      this.lastError = message;
    },

    async createBackup({ mnemonic, password }: CreateBackupPayload) {
      if (!password || password.trim().length === 0) {
        throw new Error("A password is required to create a RecoverBull backup");
      }

      const sanitizedMnemonic = mnemonic.map((word) => word.trim()).filter(Boolean);
      if (sanitizedMnemonic.length === 0) {
        throw new Error("Mnemonic cannot be empty");
      }

      this.backupInProgress = true;
      const keyServerStore = useRecoverbullKeyServerStore();

      try {
        const result = await createRecoverbullBackup(sanitizedMnemonic);
        const backupJson = JSON.stringify(result.backup, null, 2);

        await keyServerStore.storeBackupKey({
          identifier: hexToBytes(result.backup.id),
          password,
          backupKey: result.backupKey,
          salt: hexToBytes(result.backup.salt),
        });

        this.lastBackup = {
          identifierHex: result.backup.id,
          derivationPath: result.derivationPath,
          createdAt: result.createdAt,
          fileName: `recoverbull-backup-${result.backup.id}.json`,
          backupJson,
        };
        this.lastError = null;
        return this.lastBackup;
      } catch (error: any) {
        const message =
          error?.message ?? "Failed to create RecoverBull backup";
        this.lastError = message;
        throw error;
      } finally {
        this.backupInProgress = false;
      }
    },

    async restoreBackup({ backupJson, password }: RestoreBackupPayload) {
      if (!password || password.trim().length === 0) {
        throw new Error("A password is required to restore a RecoverBull backup");
      }
      if (!backupJson || backupJson.trim().length === 0) {
        throw new Error("Backup file content is required");
      }

      this.restoreInProgress = true;
      const keyServerStore = useRecoverbullKeyServerStore();

      try {
        const parsed = parseBullBackup(backupJson);
        const backupKeyBytes = await keyServerStore.fetchBackupKey({
          identifier: parsed.id,
          password,
          salt: parsed.salt,
        });
        const restored = await restoreRecoverbullBackup(
          backupJson,
          bytesToHex(backupKeyBytes)
        );

        this.lastRestore = {
          identifierHex: bytesToHex(parsed.id),
          restoredAt: Date.now(),
        };
        this.lastRestoredMnemonic = restored.mnemonic;
        this.lastError = null;

        return restored.mnemonic;
      } catch (error: any) {
        const message =
          error?.message ?? "Failed to restore RecoverBull backup";
        this.lastError = message;
        throw error;
      } finally {
        this.restoreInProgress = false;
      }
    },
  },
});


