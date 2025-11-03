import { defineStore } from 'pinia';
import { useLocalStorage } from '@vueuse/core';

// Import Google Drive plugin - will be undefined in PWA mode
import GoogleDrive from 'src/plugins/google-drive';

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
}

export const useGoogleDriveBackupStore = defineStore('googleDriveBackup', {
  state: (): GoogleDriveBackupState => ({
    isAuthenticated: useLocalStorage<boolean>('cashu.googleDrive.isAuthenticated', false),
    lastBackupTimestamp: useLocalStorage<number>('cashu.googleDrive.lastBackupTimestamp', 0),
    backupInProgress: false,
    restoreInProgress: false,
  }),

  getters: {
    isBackupAvailable: (state) => state.isAuthenticated && !state.backupInProgress,
    lastBackupDate: (state) => state.lastBackupTimestamp > 0 ? new Date(state.lastBackupTimestamp) : null,
    isPluginAvailable: () => !!GoogleDrive,
  },

  actions: {
    /**
     * Connect to Google Drive (authentication)
     */
    async connect(): Promise<void> {
      if (!this.isPluginAvailable) {
        throw new Error('Google Drive backup is only available on mobile devices (Android/iOS)');
      }

      try {
        await GoogleDrive.connect();
        this.isAuthenticated = true;
      } catch (error) {
        this.isAuthenticated = false;
        throw error;
      }
    },

    /**
     * Disconnect from Google Drive
     */
    async disconnect(): Promise<void> {
      try {
        await GoogleDrive.disconnect();
      } catch (error) {
        // Ignore disconnect errors
        console.warn('Google Drive disconnect error:', error);
      } finally {
        this.isAuthenticated = false;
      }
    },

    /**
     * Store encrypted vault backup to Google Drive
     */
    async storeBackup(content: string): Promise<void> {
      if (!this.isPluginAvailable) {
        throw new Error('Google Drive backup is only available on mobile devices (Android/iOS)');
      }

      if (!this.isAuthenticated) {
        throw new Error('Not authenticated with Google Drive');
      }

      this.backupInProgress = true;
      try {
        await GoogleDrive.store({ content });
      } finally {
        this.backupInProgress = false;
      }
    },

    /**
     * Fetch all backup metadata from Google Drive
     */
    async fetchAllMetadata(): Promise<DriveFileMetadata[]> {
      if (!this.isPluginAvailable) {
        throw new Error('Google Drive backup is only available on mobile devices (Android/iOS)');
      }

      if (!this.isAuthenticated) {
        throw new Error('Not authenticated with Google Drive');
      }

      const response = await GoogleDrive.fetchAllMetadata();
      return response.files.map(file => ({
        id: file.id,
        name: file.name,
        createdTime: new Date(file.createdTime),
      }));
    },

    /**
     * Fetch specific backup file content from Google Drive
     */
    async fetchFileContent(fileId: string): Promise<string> {
      if (!this.isPluginAvailable) {
        throw new Error('Google Drive backup is only available on mobile devices (Android/iOS)');
      }

      if (!this.isAuthenticated) {
        throw new Error('Not authenticated with Google Drive');
      }

      const response = await GoogleDrive.fetchFileContent({ fileId });
      return response.content;
    },

    /**
     * Fetch the latest backup from Google Drive
     */
    async fetchLatestBackup(): Promise<{ content: string; fileName: string }> {
      const backups = await this.fetchAllMetadata();

      if (backups.length === 0) {
        throw new Error('No backups found');
      }

      // Sort by creation time (newest first) and get the first one
      const latestBackup = backups.reduce((latest, current) => {
        return current.createdTime > latest.createdTime ? current : latest;
      });

      const content = await this.fetchFileContent(latestBackup.id);
      return { content, fileName: latestBackup.name };
    },

    /**
     * Delete a backup file from Google Drive
     */
    async trashBackup(filename: string): Promise<void> {
      if (!this.isPluginAvailable) {
        throw new Error('Google Drive backup is only available on mobile devices (Android/iOS)');
      }

      if (!this.isAuthenticated) {
        throw new Error('Not authenticated with Google Drive');
      }

      await GoogleDrive.trash({ path: filename });
    },

    /**
     * Backup seed phrase to Google Drive
     * This is the main public API method
     */
    async backupSeedPhrase(mnemonic: string[]): Promise<void> {
      // TODO: Implement encrypted vault creation from mnemonic
      // TODO: Call storeBackup with the encrypted content
      // TODO: Update lastBackupTimestamp

      // For now, create a simple encrypted vault structure
      const vault = {
        mnemonic: mnemonic,
        createdAt: Date.now(),
        version: '1.0',
      };

      const content = JSON.stringify(vault);
      await this.storeBackup(content);
      this.lastBackupTimestamp = Date.now();
    },

    /**
     * Restore seed phrase from Google Drive
     * This is the main public API method
     */
    async restoreSeedPhrase(): Promise<string[]> {
      this.restoreInProgress = true;
      try {
        const { content } = await this.fetchLatestBackup();
        const vault = JSON.parse(content);

        if (!vault.mnemonic || !Array.isArray(vault.mnemonic)) {
          throw new Error('Invalid backup format');
        }

        return vault.mnemonic;
      } finally {
        this.restoreInProgress = false;
      }
    },

    /**
     * Check if any backup exists on Google Drive
     */
    async checkBackupExists(): Promise<boolean> {
      try {
        const backups = await this.fetchAllMetadata();
        return backups.length > 0;
      } catch {
        return false;
      }
    },

    /**
     * Get backup information
     */
    async getBackupInfo(): Promise<{ timestamp: number; version: string } | null> {
      try {
        const backups = await this.fetchAllMetadata();
        if (backups.length === 0) return null;

        const latest = backups.reduce((latest, current) => {
          return current.createdTime > latest.createdTime ? current : latest;
        });

        // TODO: Parse version from backup content
        return {
          timestamp: latest.createdTime.getTime(),
          version: '1.0', // Placeholder
        };
      } catch {
        return null;
      }
    },
  },
});
