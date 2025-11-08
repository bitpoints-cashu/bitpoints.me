import { HDKey } from "@scure/bip32";
import { mnemonicToSeedSync } from "@scure/bip39";
import { hmac } from "@noble/hashes/hmac";
import { sha512 } from "@noble/hashes/sha512";
import { sha256 } from "@noble/hashes/sha256";
import { utf8ToBytes } from "@noble/hashes/utils";

// Buffer is available in Node environments; declare for TypeScript awareness.
declare const Buffer: any;

const RECOVERBULL_APPLICATION = 1608;
const BIP85_ROOT = "m/83696968'";
const BIP_ENTROPY_KEY = utf8ToBytes("bip-entropy-from-k");
const AES_BLOCK_SIZE = 16;

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

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

function hexToBytes(hex: string): Uint8Array {
  if (hex.length % 2 !== 0) {
    throw new Error("Invalid hex string");
  }
  const bytes = new Uint8Array(hex.length / 2);
  for (let i = 0; i < bytes.length; i++) {
    bytes[i] = parseInt(hex.substr(i * 2, 2), 16);
  }
  return bytes;
}

function bytesToBase64(bytes: Uint8Array): string {
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

function base64ToBytes(value: string): Uint8Array {
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

function generateRandomBytes(length: number): Uint8Array {
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
  return hmacDigest.slice(0, 32);
}

export interface RecoverbullVaultPayload {
  mnemonic: string[];
  version: string;
  createdAt: number;
}

export interface RecoverbullVaultResult {
  vaultJson: string;
  vaultKeyHex: string;
  derivationPath: string;
  createdAt: number;
}

export async function createRecoverbullVault(
  mnemonicWords: string[],
  options: { index?: number } = {}
): Promise<RecoverbullVaultResult> {
  const mnemonic = mnemonicWords.join(" ").trim();
  if (!mnemonic) {
    throw new Error("Mnemonic cannot be empty");
  }

  const payload: RecoverbullVaultPayload = {
    mnemonic: mnemonicWords,
    version: "1.0",
    createdAt: Date.now(),
  };
  const encoder = new TextEncoder();
  const plaintext = encoder.encode(JSON.stringify(payload));
  const paddedPlaintext = pkcs7Pad(plaintext);

  const seed = mnemonicToSeedSync(mnemonic);
  const index =
    options.index ??
    (generateRandomBytes(4).reduce(
      (acc, byte, i) => acc + byte * 2 ** (8 * i),
      0
    ) &
      0x7fffffff);
  const derivationPath = getRecoverbullPath(index);
  const backupKey = deriveBackupKey(seed, derivationPath);

  const iv = generateRandomBytes(16);
  const ciphertext = await aesCbcEncrypt(backupKey, iv, paddedPlaintext);
  const hmacDigest = hmac(sha256, backupKey, concatBytes(iv, ciphertext));

  const id = generateRandomBytes(32);
  const salt = generateRandomBytes(16);

  const vault = {
    created_at: payload.createdAt,
    id: bytesToHex(id),
    ciphertext: bytesToBase64(concatBytes(iv, ciphertext, hmacDigest)),
    salt: bytesToHex(salt),
    path: derivationPath,
  };

  return {
    vaultJson: JSON.stringify(vault),
    vaultKeyHex: bytesToHex(backupKey),
    derivationPath,
    createdAt: payload.createdAt,
  };
}

export interface RecoverbullVaultDecoded {
  mnemonic: string[];
  createdAt: number;
  version: string;
}

export async function restoreRecoverbullVault(
  vaultJson: string,
  vaultKeyHex: string
): Promise<RecoverbullVaultDecoded> {
  if (!vaultKeyHex) {
    throw new Error("Vault key is required to restore backup");
  }

  const vault = JSON.parse(vaultJson) as {
    ciphertext: string;
    path: string;
  };

  const backupKey = hexToBytes(vaultKeyHex);
  const blob = base64ToBytes(vault.ciphertext);
  if (blob.length <= 16 + 32) {
    throw new Error("Invalid ciphertext payload");
  }
  const iv = blob.slice(0, 16);
  const hmacOffset = blob.length - 32;
  const ciphertext = blob.slice(16, hmacOffset);
  const hmacProvided = blob.slice(hmacOffset);

  const hmacExpected = hmac(sha256, backupKey, blob.slice(0, hmacOffset));
  if (hmacExpected.length !== hmacProvided.length) {
    throw new Error("Invalid vault authentication tag");
  }
  for (let i = 0; i < hmacExpected.length; i++) {
    if (hmacExpected[i] !== hmacProvided[i]) {
      throw new Error("Vault authentication failed");
    }
  }

  const paddedPlaintext = await aesCbcDecrypt(backupKey, iv, ciphertext);
  const plaintext = pkcs7Unpad(paddedPlaintext);
  const decoder = new TextDecoder();
  const payload = JSON.parse(decoder.decode(plaintext)) as RecoverbullVaultPayload;

  return {
    mnemonic: payload.mnemonic,
    createdAt: payload.createdAt,
    version: payload.version,
  };
}

export function normalizeRecoverbullPath(path: string): string {
  return normalizePath(path);
}

