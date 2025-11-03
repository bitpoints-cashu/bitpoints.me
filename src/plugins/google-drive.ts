import { registerPlugin } from '@capacitor/core';

export interface GoogleDrivePlugin {
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  store(options: { content: string }): Promise<void>;
  fetchAllMetadata(): Promise<{ files: DriveFileMetadata[] }>;
  fetchFileContent(options: { fileId: string }): Promise<{ content: string }>;
  trash(options: { path: string }): Promise<void>;
}

export interface DriveFileMetadata {
  id: string;
  name: string;
  createdTime: string; // ISO string
}

const GoogleDrive = registerPlugin<GoogleDrivePlugin>('GoogleDrive');

export default GoogleDrive;
