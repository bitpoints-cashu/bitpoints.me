import axios, { AxiosError, AxiosInstance } from "axios";
import {
  base64ToBytes,
  bytesToBase64,
  bytesToHex,
  computePasswordKeys,
  decodeEnvelope,
  decryptWithKey,
  encodeEnvelope,
  encryptWithKey,
} from "src/utils/recoverbullVault";

const envKeyServerUrl =
  typeof import.meta !== "undefined" && import.meta?.env
    ? import.meta.env.VITE_RECOVERBULL_KEY_SERVER_URL
    : undefined;

export const DEFAULT_KEY_SERVER_URL =
  (typeof envKeyServerUrl === "string" && envKeyServerUrl.trim().length > 0
    ? envKeyServerUrl.trim()
    : undefined) ?? "http://keys.bitpints.me";

export interface KeyServerClientConfig {
  baseUrl?: string;
  timeoutMs?: number;
  headers?: Record<string, string>;
}

export interface KeyServerInfo {
  cooldown_minutes: number;
  max_attempts: number;
  canary: string;
  signature?: string;
  version?: string;
}

export interface KeyServerErrorPayload {
  error?: string;
  requested_at?: string;
  rate_limit_cooldown?: number;
  attempts?: number;
}

export interface KeyServerStorePayload {
  identifier: Uint8Array;
  password: string;
  backupKey: Uint8Array;
  salt: Uint8Array;
}

export interface KeyServerFetchPayload {
  identifier: Uint8Array;
  password: string;
  salt: Uint8Array;
}

export class RecoverbullKeyServerError extends Error {
  readonly code?: number;
  readonly requestedAt?: string;
  readonly cooldownMinutes?: number;
  readonly attempts?: number;

  constructor(message: string, options: Partial<RecoverbullKeyServerError> = {}) {
    super(message);
    this.name = "RecoverbullKeyServerError";
    this.code = options.code;
    this.requestedAt = options.requestedAt;
    this.cooldownMinutes = options.cooldownMinutes;
    this.attempts = options.attempts;
  }
}

function normalizeErrorPayload(payload: KeyServerErrorPayload = {}): Partial<RecoverbullKeyServerError> {
  return {
    requestedAt: payload.requested_at,
    cooldownMinutes: payload.rate_limit_cooldown,
    attempts: payload.attempts,
  };
}

function createHttpClient(config: KeyServerClientConfig): AxiosInstance {
  const baseURL = (config.baseUrl ?? DEFAULT_KEY_SERVER_URL).replace(/\/+$/, "");

  return axios.create({
    baseURL,
    timeout: config.timeoutMs ?? 10_000,
    headers: {
      Accept: "application/json",
      "Content-Type": "application/json",
      ...(config.headers ?? {}),
    },
  });
}

export class RecoverbullKeyServerClient {
  private readonly http: AxiosInstance;

  constructor(private readonly config: KeyServerClientConfig = {}) {
    this.http = createHttpClient(config);
  }

  async getInfo(): Promise<KeyServerInfo> {
    try {
      const response = await this.http.get<KeyServerInfo>("/info");
      return response.data;
    } catch (error) {
      throw this.toKeyServerError(error);
    }
  }

  async storeBackupKey(payload: KeyServerStorePayload): Promise<void> {
    try {
      const derived = computePasswordKeys(payload.password, payload.salt);
      const encryptedEnvelope = await encryptWithKey(
        derived.encryptionKey,
        payload.backupKey
      );
      const merged = encodeEnvelope(encryptedEnvelope);

      await this.http.post(
        "/store",
        {
          identifier: bytesToHex(payload.identifier),
          authentication_key: bytesToHex(derived.authenticationKey),
          encrypted_secret: bytesToBase64(merged),
        },
        {
          validateStatus: (status) => status === 201,
        }
      );
    } catch (error) {
      throw this.toKeyServerError(error);
    }
  }

  async fetchBackupKey(payload: KeyServerFetchPayload): Promise<Uint8Array> {
    return this.retrieveEncryptedSecret(payload, "/fetch");
  }

  async trashBackupKey(payload: KeyServerFetchPayload): Promise<Uint8Array> {
    return this.retrieveEncryptedSecret(payload, "/trash");
  }

  private async retrieveEncryptedSecret(
    payload: KeyServerFetchPayload,
    endpoint: "/fetch" | "/trash"
  ): Promise<Uint8Array> {
    try {
      const derived = computePasswordKeys(payload.password, payload.salt);

      const response = await this.http.post<{ encrypted_secret: string }>(
        endpoint,
        {
          identifier: bytesToHex(payload.identifier),
          authentication_key: bytesToHex(derived.authenticationKey),
        },
        {
          validateStatus: (status) => status === 200 || status === 202,
        }
      );

      const blob = base64ToBytes(response.data.encrypted_secret);
      const envelope = decodeEnvelope(blob);
      const backupKey = await decryptWithKey(derived.encryptionKey, envelope);

      return backupKey;
    } catch (error) {
      throw this.toKeyServerError(error);
    }
  }

  private toKeyServerError(error: unknown): RecoverbullKeyServerError {
    if (error instanceof RecoverbullKeyServerError) {
      return error;
    }

    if (axios.isAxiosError<KeyServerErrorPayload>(error)) {
      const axiosError = error as AxiosError<KeyServerErrorPayload>;
      const status = axiosError.response?.status;
      const payload = axiosError.response?.data;
      const normalized = normalizeErrorPayload(payload);
      const message =
        payload?.error ??
        axiosError.message ??
        "RecoverBull key server request failed";
      return new RecoverbullKeyServerError(message, {
        code: status,
        ...normalized,
      });
    }

    if (error instanceof Error) {
      return new RecoverbullKeyServerError(error.message);
    }

    return new RecoverbullKeyServerError("Unknown key server error");
  }
}


