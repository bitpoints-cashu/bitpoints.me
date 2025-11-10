import { HDKey } from "@scure/bip32";
import { mnemonicToSeedSync } from "@scure/bip39";
import { hmac } from "@noble/hashes/hmac";
import { sha256 } from "@noble/hashes/sha256";
import { sha512 } from "@noble/hashes/sha512";
import { utf8ToBytes } from "@noble/hashes/utils";
import { argon2id } from "@noble/hashes/argon2";

// Buffer is available in Node environments; declare for TypeScript awareness.
declare const Buffer: any;

const RECOVERBULL_APPLICATION = 1608;
const BIP85_ROOT = "m/83696968'";
const BIP_ENTROPY_KEY = utf8ToBytes("bip-entropy-from-k");
const AES_BLOCK_SIZE = 16;
export const ARGON2_ITERATIONS = 2;
export const ARGON2_MEMORY_KIB = 19 * 1024;
export const ARGON2_PARALLELISM = 1;
export const ARGON2_KEY_BYTES = 32;

export const ARGON2_DEFAULTS = {
  iterations: ARGON2_ITERATIONS,
  memoryKiB: ARGON2_MEMORY_KIB,
  parallelism: ARGON2_PARALLELISM,
  keyBytes: ARGON2_KEY_BYTES,
} as const;

export const RECOVERBULL_PAYLOAD_VERSION = "1.0";

export interface RecoverbullPayload {
  mnemonic: string[];
  version: string;
  createdAt: number;
}

export interface BullBackup {
  created_at: number;
  id: string;
  ciphertext: string;
  salt: string;
  path?: string;
}

export interface BullBackupParsed {
  createdAt: number;
  id: Uint8Array;
  ciphertext: Uint8Array;
  salt: Uint8Array;
  path?: string;
}

export interface EncryptionEnvelope {
  nonce: Uint8Array;
  ciphertext: Uint8Array;
  hmac: Uint8Array;
}

export interface PasswordDerivedKeys {
  authenticationKey: Uint8Array;
  encryptionKey: Uint8Array;
  combinedKey: Uint8Array;
}

export interface CreateRecoverbullBackupOptions {
  index?: number;
  derivationPath?: string;
  createdAt?: number;
  salt?: Uint8Array;
  randomBytes?: (length: number) => Uint8Array;
}

export interface CreateRecoverbullBackupResult {
  backup: BullBackup;
  backupKey: Uint8Array;
  backupKeyHex: string;
  derivationPath: string;
  createdAt: number;
}

export interface RecoverbullRestoreResult {
  mnemonic: string[];
  createdAt: number;
  version: string;
}

function getCrypto(): Crypto {
  if (typeof globalThis.crypto !== "undefined") {
    return globalThis.crypto;
  }
  throw new Error("Web Crypto API is not available in this environment");
}

function concatBytes(...arrays: Uint8Array[]): Uint8Array {
  const totalLength = arrays.reduce((sum, arr) => sum + arr.length, 0);
  const output = new Uint8Array(totalLength);
  let offset = 0;
  for (const arr of arrays) {
    output.set(arr, offset);
    offset += arr.length;
  }
  return output;
}

export function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

export function hexToBytes(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new Error("Invalid hex string");
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return bytes;
}

export function bytesToBase64(bytes: Uint8Array): string {
  if (typeof Buffer !== "undefined") {
    return Buffer.from(bytes).toString("base64");
  }

  let binary = "";
  const len = bytes.byteLength;
  for (let i = 0; i < len; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}

export function base64ToBytes(value: string): Uint8Array {
  if (typeof Buffer !== "undefined") {
    return new Uint8Array(Buffer.from(value, "base64"));
  }

  const binary = atob(value);
  const len = binary.length;
  const bytes = new Uint8Array(len);
  for (let i = 0; i < len; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function constantTimeEqual(a: Uint8Array, b: Uint8Array): boolean {
  if (a.length !== b.length) {
    return false;
  }
  let diff = 0;
  for (let i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff === 0;
}

function pkcs7Pad(input: Uint8Array, blockSize = AES_BLOCK_SIZE): Uint8Array {
  const padLength = blockSize - (input.length % blockSize);
  const output = new Uint8Array(input.length + padLength);
  output.set(input);
  output.fill(padLength, input.length);
  return output;
}

function pkcs7Unpad(input: Uint8Array, blockSize = AES_BLOCK_SIZE): Uint8Array {
  if (input.length === 0 || input.length % blockSize !== 0) {
    throw new Error("Invalid padded data");
  }
  const padLength = input[input.length - 1];
  if (padLength <= 0 || padLength > blockSize) {
    throw new Error("Invalid PKCS7 padding");
  }
  for (let i = input.length - padLength; i < input.length; i++) {
    if (input[i] !== padLength) {
      throw new Error("Invalid PKCS7 padding");
    }
  }
  return input.slice(0, input.length - padLength);
}

async function aesCbcEncrypt(
  key: Uint8Array,
  iv: Uint8Array,
  data: Uint8Array
): Promise<Uint8Array> {
  const crypto = getCrypto();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "AES-CBC" },
    false,
    ["encrypt"]
  );
  const ciphertext = await crypto.subtle.encrypt(
    { name: "AES-CBC", iv },
    cryptoKey,
    data
  );
  return new Uint8Array(ciphertext);
}

async function aesCbcDecrypt(
  key: Uint8Array,
  iv: Uint8Array,
  data: Uint8Array
): Promise<Uint8Array> {
  const crypto = getCrypto();
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    key,
    { name: "AES-CBC" },
    false,
    ["decrypt"]
  );
  const plaintext = await crypto.subtle.decrypt(
    { name: "AES-CBC", iv },
    cryptoKey,
    data
  );
  return new Uint8Array(plaintext);
}

export function randomBytes(length: number): Uint8Array {
  const output = new Uint8Array(length);
  getCrypto().getRandomValues(output);
  return output;
}

function getRecoverbullPath(index: number): string {
  return `${RECOVERBULL_APPLICATION}'/0'/${index}'`;
}

function normalizePath(path: string): string {
  const cleaned = path.startsWith("m/") ? path.slice(2) : path;
  return `${RECOVERBULL_APPLICATION}'/${cleaned}`;
}

function buildFullBip85Path(path: string): string {
  const cleaned = path.startsWith("m/") ? path.slice(2) : path;
  return `${BIP85_ROOT}/${cleaned}`;
}

function deriveBackupKey(seed: Uint8Array, path: string): Uint8Array {
  const fullPath = buildFullBip85Path(path);
  const root = HDKey.fromMasterSeed(seed);
  const child = root.derive(fullPath);
  if (!child.privateKey) {
    throw new Error("Unable to derive backup key (missing private key)");
  }
  const hmacDigest = hmac(sha512, BIP_ENTROPY_KEY, child.privateKey);
  return hmacDigest.slice(0, ARGON2_KEY_BYTES);
}

function ensureMnemonic(words: string[]): string[] {
  const normalized = words.map((word) => word.trim()).filter(Boolean);
  if (!normalized.length) {
    throw new Error("Mnemonic cannot be empty");
  }
  return normalized;
}

function toPayload(mnemonicWords: string[], createdAt: number): RecoverbullPayload {
  return {
    mnemonic: mnemonicWords,
    version: RECOVERBULL_PAYLOAD_VERSION,
    createdAt,
  };
}

export function encodeEnvelope(envelope: EncryptionEnvelope): Uint8Array {
  if (envelope.nonce.length !== 16) {
    throw new Error("Invalid nonce length");
  }
  if (envelope.hmac.length !== 32) {
    throw new Error("Invalid HMAC length");
  }
  return concatBytes(envelope.nonce, envelope.ciphertext, envelope.hmac);
}

export function decodeEnvelope(blob: Uint8Array): EncryptionEnvelope {
  if (blob.length < 16 + 32 + 1) {
    throw new Error("Invalid envelope length");
  }
  const nonce = blob.slice(0, 16);
  const hmacOffset = blob.length - 32;
  const ciphertext = blob.slice(16, hmacOffset);
  const hmacBytes = blob.slice(hmacOffset);
  if (nonce.length !== 16 || hmacBytes.length !== 32 || ciphertext.length === 0) {
    throw new Error("Malformed encryption envelope");
  }
  return { nonce, ciphertext, hmac: hmacBytes };
}

export async function encryptWithKey(
  key: Uint8Array,
  plaintext: Uint8Array,
  randomFn: (length: number) => Uint8Array = randomBytes
): Promise<EncryptionEnvelope> {
  if (key.length !== ARGON2_KEY_BYTES) {
    throw new Error("Encryption key must be 32 bytes");
  }

  const nonce = randomFn(16);
  const padded = pkcs7Pad(plaintext);
  const ciphertext = await aesCbcEncrypt(key, nonce, padded);
  const hmacDigest = hmac(sha256, key, concatBytes(nonce, ciphertext));

  return { nonce, ciphertext, hmac: hmacDigest };
}

export async function decryptWithKey(
  key: Uint8Array,
  envelope: EncryptionEnvelope
): Promise<Uint8Array> {
  if (key.length !== ARGON2_KEY_BYTES) {
    throw new Error("Encryption key must be 32 bytes");
  }

  const hmacDigest = hmac(
    sha256,
    key,
    concatBytes(envelope.nonce, envelope.ciphertext)
  );

  if (!constantTimeEqual(hmacDigest, envelope.hmac)) {
    throw new Error("Encryption authentication failed");
  }

  const paddedPlaintext = await aesCbcDecrypt(
    key,
    envelope.nonce,
    envelope.ciphertext
  );

  return pkcs7Unpad(paddedPlaintext);
}

export function computePasswordKeys(
  password: string,
  salt: Uint8Array,
  keySize = ARGON2_KEY_BYTES
): PasswordDerivedKeys {
  if (!password) {
    throw new Error("Password is required");
  }
  if (salt.length !== 16) {
    throw new Error("Salt must be 16 bytes");
  }

  const derived = argon2id(utf8ToBytes(password), salt, {
    t: ARGON2_ITERATIONS,
    m: ARGON2_MEMORY_KIB,
    p: ARGON2_PARALLELISM,
    dkLen: keySize * 2,
  });

  const authenticationKey = derived.slice(0, keySize);
  const encryptionKey = derived.slice(keySize);

  return {
    authenticationKey,
    encryptionKey,
    combinedKey: derived,
  };
}

export function parseBullBackup(input: string | BullBackup): BullBackupParsed {
  const data: BullBackup =
    typeof input === "string" ? (JSON.parse(input) as BullBackup) : input;

  if (
    typeof data.created_at !== "number" ||
    typeof data.id !== "string" ||
    typeof data.ciphertext !== "string" ||
    typeof data.salt !== "string"
  ) {
    throw new Error("Invalid BullBackup payload");
  }

  return {
    createdAt: data.created_at,
    id: hexToBytes(data.id),
    ciphertext: base64ToBytes(data.ciphertext),
    salt: hexToBytes(data.salt),
    path: data.path,
  };
}

export function encodeBullBackup(parsed: BullBackupParsed): BullBackup {
  return {
    created_at: parsed.createdAt,
    id: bytesToHex(parsed.id),
    ciphertext: bytesToBase64(parsed.ciphertext),
    salt: bytesToHex(parsed.salt),
    path: parsed.path,
  };
}

export async function createRecoverbullBackup(
  mnemonicWords: string[],
  options: CreateRecoverbullBackupOptions = {}
): Promise<CreateRecoverbullBackupResult> {
  const normalizedMnemonic = ensureMnemonic(mnemonicWords);
  const createdAt = options.createdAt ?? Date.now();
  const payload = toPayload(normalizedMnemonic, createdAt);

  const encoder = new TextEncoder();
  const plaintext = encoder.encode(JSON.stringify(payload));

  const randomFn = options.randomBytes ?? randomBytes;
  const salt = options.salt ?? randomFn(16);
  const rawIndex =
    options.index ??
    (randomFn(4).reduce((acc, byte, i) => acc + byte * 2 ** (8 * i), 0) &
      0x7fffffff);

  const derivationPath =
    options.derivationPath ?? getRecoverbullPath(rawIndex);

  const mnemonic = normalizedMnemonic.join(" ");
  const seed = mnemonicToSeedSync(mnemonic);
  const backupKey = deriveBackupKey(seed, derivationPath);

  const envelope = await encryptWithKey(backupKey, plaintext, randomFn);
  const blob = encodeEnvelope(envelope);

  const backup: BullBackup = {
    created_at: createdAt,
    id: bytesToHex(randomFn(32)),
    ciphertext: bytesToBase64(blob),
    salt: bytesToHex(salt),
    path: derivationPath,
  };

  return {
    backup,
    backupKey,
    backupKeyHex: bytesToHex(backupKey),
    derivationPath,
    createdAt,
  };
}

export async function restoreRecoverbullBackup(
  backupInput: string | BullBackup,
  backupKeyHex: string
): Promise<RecoverbullRestoreResult> {
  if (!backupKeyHex) {
    throw new Error("Backup key is required");
  }

  const backup = parseBullBackup(backupInput);
  const envelope = decodeEnvelope(backup.ciphertext);
  const backupKey = hexToBytes(backupKeyHex);

  const plaintext = await decryptWithKey(backupKey, envelope);
  const decoder = new TextDecoder();
  const payload = JSON.parse(decoder.decode(plaintext)) as RecoverbullPayload;

  return {
    mnemonic: ensureMnemonic(payload.mnemonic),
    createdAt: payload.createdAt,
    version: payload.version,
  };
}

export function normalizeRecoverbullPath(path: string): string {
  return normalizePath(path);
}

