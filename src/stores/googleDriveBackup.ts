import { defineStore } from "pinia";
import { useLocalStorage } from "@vueuse/core";
import GoogleDrive from "src/plugins/google-drive";
import {
  createRecoverbullVault,
  restoreRecoverbullVault,
} from "src/utils/recoverbullVault";

export interface DriveFileMetadata {
  id: string;
  name: string;
  createdTime: Date;
}

export interface GoogleDriveBackupState {
  isAuthenticated: boolean;
  lastBackupTimestamp: number;
  backupInProgress: boolean;
  restoreInProgress: boolean;
  backupFiles: DriveFileMetadata[];
  lastError: string | null;
  vaultKeyHex: string;
}

const AUTH_STORAGE_KEY = "cashu.googleDrive.isAuthenticated";
const BACKUP_TIMESTAMP_KEY = "cashu.googleDrive.lastBackupTimestamp";
const VAULT_KEY_STORAGE = "cashu.googleDrive.vaultKey";

export const useGoogleDriveBackupStore = defineStore("googleDriveBackup", {
  state: (): GoogleDriveBackupState => ({
    isAuthenticated: useLocalStorage<boolean>(AUTH_STORAGE_KEY, false),
    lastBackupTimestamp: useLocalStorage<number>(BACKUP_TIMESTAMP_KEY, 0),
    backupInProgress: false,
    restoreInProgress: false,
    backupFiles: [],
    lastError: null,
    vaultKeyHex: useLocalStorage<string>(VAULT_KEY_STORAGE, ""),
  }),

  getters: {
    isBackupAvailable: (state) =>
      state.isAuthenticated && !state.backupInProgress,
    lastBackupDate: (state) =>
      state.lastBackupTimestamp > 0
        ? new Date(state.lastBackupTimestamp)
        : null,
    isPluginAvailable: () => !!GoogleDrive,
    backupCount: (state) => state.backupFiles.length,
    latestBackup: (state) =>
      state.backupFiles.length > 0 ? state.backupFiles[0] : null,
    latestBackupLabel(): string {
      if (!this.latestBackup) {
        return "Never";
      }

      try {
        return `${this.latestBackup.name} • ${this.latestBackup.createdTime.toLocaleString()}`;
      } catch {
        return this.latestBackup.createdTime.toISOString();
      }
    },
    hasVaultKey: (state) => state.vaultKeyHex.length > 0,
  },

  actions: {
    setAuthenticated(value: boolean) {
      this.isAuthenticated = value;
    },

    setLastBackupTimestamp(timestamp: number) {
      this.lastBackupTimestamp = timestamp;
    },

    setVaultKey(keyHex: string) {
      this.vaultKeyHex = keyHex.trim();
    },

    clearVaultKey() {
      this.vaultKeyHex = "";
    },

    resetState() {
      this.backupFiles = [];
      this.lastError = null;
      this.setAuthenticated(false);
      this.setLastBackupTimestamp(0);
      this.clearVaultKey();
    },

    updateBackupFiles(files: DriveFileMetadata[]) {
      this.backupFiles = files;
      if (files.length > 0) {
        this.setLastBackupTimestamp(files[0].createdTime.getTime());
      }
    },

    setLastError(message: string | null) {
      this.lastError = message;
    },

    async refreshBackupMetadata(): Promise<void> {
      if (!this.isPluginAvailable || !this.isAuthenticated) {
        this.updateBackupFiles([]);
        return;
      }

      try {
        const response = await GoogleDrive.fetchAllMetadata();
        const files = response.files
          .map((file) => ({
            id: file.id,
            name: file.name,
            createdTime: new Date(file.createdTime),
          }))
          .sort((a, b) => b.createdTime.getTime() - a.createdTime.getTime());

        this.updateBackupFiles(files);
        this.setLastError(null);
      } catch (error: any) {
        console.error("Failed to refresh Google Drive backups:", error);
        this.setLastError(
          error?.message ?? "Failed to load Google Drive backups"
        );
      }
    },

    async connect(): Promise<void> {
      if (!this.isPluginAvailable) {
        throw new Error(
          "Google Drive backup is only available on mobile devices (Android/iOS)"
        );
      }

      try {
        await GoogleDrive.connect();
        this.setAuthenticated(true);
        await this.refreshBackupMetadata();
      } catch (error) {
        this.setAuthenticated(false);
        throw error;
      }
    },

    async disconnect(): Promise<void> {
      try {
        await GoogleDrive.disconnect();
      } catch (error) {
        console.warn("Google Drive disconnect error:", error);
      } finally {
        this.resetState();
      }
    },

    async storeBackup(content: string): Promise<void> {
      if (!this.isPluginAvailable) {
        throw new Error(
          "Google Drive backup is only available on mobile devices (Android/iOS)"
        );
      }

      if (!this.isAuthenticated) {
        throw new Error("Not authenticated with Google Drive");
      }

      this.backupInProgress = true;
      try {
        await GoogleDrive.store({ content });
        await this.refreshBackupMetadata();
      } finally {
        this.backupInProgress = false;
      }
    },

    async fetchAllMetadata(): Promise<DriveFileMetadata[]> {
      if (!this.isPluginAvailable) {
        throw new Error(
          "Google Drive backup is only available on mobile devices (Android/iOS)"
        );
      }

      if (!this.isAuthenticated) {
        throw new Error("Not authenticated with Google Drive");
      }

      await this.refreshBackupMetadata();
      return this.backupFiles;
    },

    async fetchFileContent(fileId: string): Promise<string> {
      if (!this.isPluginAvailable) {
        throw new Error(
          "Google Drive backup is only available on mobile devices (Android/iOS)"
        );
      }

      if (!this.isAuthenticated) {
        throw new Error("Not authenticated with Google Drive");
      }

      const response = await GoogleDrive.fetchFileContent({ fileId });
      return response.content;
    },

    async fetchLatestBackup(): Promise<{ content: string; fileName: string }> {
      const backups = await this.fetchAllMetadata();

      if (backups.length === 0) {
        throw new Error("No backups found");
      }

      const latestBackup = backups.reduce((latest, current) =>
        current.createdTime > latest.createdTime ? current : latest
      );

      const content = await this.fetchFileContent(latestBackup.id);
      return { content, fileName: latestBackup.name };
    },

    async trashBackup(filename: string): Promise<void> {
      if (!this.isPluginAvailable) {
        throw new Error(
          "Google Drive backup is only available on mobile devices (Android/iOS)"
        );
      }

      if (!this.isAuthenticated) {
        throw new Error("Not authenticated with Google Drive");
      }

      await GoogleDrive.trash({ path: filename });
    },

    async backupSeedPhrase(mnemonic: string[]): Promise<string> {
      const { vaultJson, vaultKeyHex, createdAt } =
        await createRecoverbullVault(mnemonic);

      await this.storeBackup(vaultJson);
      this.setVaultKey(vaultKeyHex);
      this.setLastBackupTimestamp(createdAt);
      await this.refreshBackupMetadata();
      return vaultKeyHex;
    },

    async restoreSeedPhrase(): Promise<string[]> {
      if (!this.vaultKeyHex) {
        throw new Error(
          "A vault key is required to decrypt the Google Drive backup"
        );
      }

      this.restoreInProgress = true;
      try {
        const { content } = await this.fetchLatestBackup();
        const restored = await restoreRecoverbullVault(
          content,
          this.vaultKeyHex
        );

        if (!Array.isArray(restored.mnemonic)) {
          throw new Error("Invalid backup payload");
        }

        return restored.mnemonic;
      } finally {
        this.restoreInProgress = false;
      }
    },

    async checkBackupExists(): Promise<boolean> {
      try {
        const backups = await this.fetchAllMetadata();
        return backups.length > 0;
      } catch {
        this.updateBackupFiles([]);
        return false;
      }
    },

    async getBackupInfo(): Promise<{ timestamp: number; version: string } | null> {
      try {
        const backups = await this.fetchAllMetadata();
        if (backups.length === 0) return null;

        const latest = backups.reduce((latest, current) =>
          current.createdTime > latest.createdTime ? current : latest
        );

        return {
          timestamp: latest.createdTime.getTime(),
          version: "1.0",
        };
      } catch {
        return null;
      }
    },
  },
});
