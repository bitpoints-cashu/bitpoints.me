declare const Buffer: any;

const PBKDF2_ITERATIONS = 310_000;
const SALT_LENGTH = 16;
const IV_LENGTH = 12;
const KEY_LENGTH = 256; // bits
const ALGORITHM = "AES-GCM";
const VERSION = "1.0";
const DEFAULT_FILENAME_PREFIX = "bitpoints-encrypted-vault";

const encoder = new TextEncoder();
const decoder = new TextDecoder();

const isBrowserCryptoAvailable =
  typeof globalThis !== "undefined" &&
  globalThis.crypto &&
  globalThis.crypto.subtle;

if (!isBrowserCryptoAvailable) {
  console.warn(
    "[passphraseVault] Web Crypto API not detected. Encryption utilities will throw when invoked."
  );
}

function toBase64(bytes: Uint8Array): string {
  if (typeof Buffer !== "undefined") {
    return Buffer.from(bytes).toString("base64");
  }
  let binary = "";
  bytes.forEach((b) => {
    binary += String.fromCharCode(b);
  });
  return btoa(binary);
}

function fromBase64(value: string): Uint8Array {
  if (typeof Buffer !== "undefined") {
    return new Uint8Array(Buffer.from(value, "base64"));
  }
  const binary = atob(value);
  const output = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    output[i] = binary.charCodeAt(i);
  }
  return output;
}

function randomBytes(length: number): Uint8Array {
  if (!isBrowserCryptoAvailable) {
    throw new Error("Secure random generator is unavailable in this environment.");
  }
  const array = new Uint8Array(length);
  globalThis.crypto.getRandomValues(array);
  return array;
}

async function deriveKey(
  passphrase: string,
  salt: Uint8Array,
  iterations = PBKDF2_ITERATIONS
): Promise<CryptoKey> {
  if (!isBrowserCryptoAvailable) {
    throw new Error("Web Crypto API is required for passphrase-based encryption.");
  }
  const baseKey = await globalThis.crypto.subtle.importKey(
    "raw",
    encoder.encode(passphrase),
    "PBKDF2",
    false,
    ["deriveKey"]
  );
  return globalThis.crypto.subtle.deriveKey(
    {
      name: "PBKDF2",
      salt,
      iterations,
      hash: "SHA-256",
    },
    baseKey,
    {
      name: ALGORITHM,
      length: KEY_LENGTH,
    },
    false,
    ["encrypt", "decrypt"]
  );
}

export interface PassphraseEncryptedVault {
  version: string;
  algorithm: string;
  ciphertext: string;
  salt: string;
  iv: string;
  iterations: number;
  createdAt: number;
  note?: string;
}

function normaliseMnemonic(mnemonic: string[]): string[] {
  return mnemonic.map((word) => word.trim().toLowerCase());
}

export async function encryptMnemonicWithPassphrase(
  mnemonic: string[],
  passphrase: string,
  note?: string
): Promise<PassphraseEncryptedVault> {
  if (!passphrase || passphrase.trim().length < 6) {
    throw new Error("Passphrase must be at least 6 characters long.");
  }
  const salt = randomBytes(SALT_LENGTH);
  const iv = randomBytes(IV_LENGTH);
  const key = await deriveKey(passphrase, salt, PBKDF2_ITERATIONS);
  const payload = JSON.stringify({
    mnemonic: normaliseMnemonic(mnemonic),
    createdAt: Date.now(),
    version: VERSION,
    note: note || null,
  });
  const encrypted = await globalThis.crypto.subtle.encrypt(
    {
      name: ALGORITHM,
      iv,
    },
    key,
    encoder.encode(payload)
  );

  return {
    version: VERSION,
    algorithm: ALGORITHM,
    ciphertext: toBase64(new Uint8Array(encrypted)),
    salt: toBase64(salt),
    iv: toBase64(iv),
    iterations: PBKDF2_ITERATIONS,
    createdAt: Date.now(),
    note,
  };
}

export async function decryptMnemonicWithPassphrase(
  vault: PassphraseEncryptedVault,
  passphrase: string
): Promise<{ mnemonic: string[]; createdAt: number; note?: string | null }> {
  const salt = fromBase64(vault.salt);
  const iv = fromBase64(vault.iv);
  const ciphertext = fromBase64(vault.ciphertext);
  const key = await deriveKey(passphrase, salt, vault.iterations || PBKDF2_ITERATIONS);
  const decrypted = await globalThis.crypto.subtle.decrypt(
    {
      name: vault.algorithm,
      iv,
    },
    key,
    ciphertext
  );
  const decoded = JSON.parse(decoder.decode(decrypted));
  return {
    mnemonic: decoded.mnemonic,
    createdAt: decoded.createdAt,
    note: decoded.note ?? null,
  };
}

export function serializeEncryptedVault(
  vault: PassphraseEncryptedVault,
  pretty = true
): string {
  return JSON.stringify(vault, null, pretty ? 2 : undefined);
}

function normaliseVaultFromJson(payload: any): PassphraseEncryptedVault {
  if (typeof payload !== "object" || payload === null) {
    throw new Error("Encrypted payload is not a valid JSON object.");
  }
  const {
    ciphertext,
    salt,
    iv,
    version,
    algorithm,
    iterations,
    createdAt,
    note,
  } = payload as Record<string, unknown>;

  if (typeof ciphertext !== "string" || ciphertext.trim() === "") {
    throw new Error("Encrypted payload is missing ciphertext.");
  }
  if (typeof salt !== "string" || salt.trim() === "") {
    throw new Error("Encrypted payload is missing salt.");
  }
  if (typeof iv !== "string" || iv.trim() === "") {
    throw new Error("Encrypted payload is missing IV.");
  }

  const parsedIterations =
    typeof iterations === "number" && Number.isFinite(iterations)
      ? iterations
      : PBKDF2_ITERATIONS;

  const parsedCreatedAt =
    typeof createdAt === "number" && Number.isFinite(createdAt)
      ? createdAt
      : Date.now();

  return {
    ciphertext: ciphertext.trim(),
    salt: salt.trim(),
    iv: iv.trim(),
    version: typeof version === "string" ? version.trim() : VERSION,
    algorithm: typeof algorithm === "string" ? algorithm.trim() : ALGORITHM,
    iterations: parsedIterations,
    createdAt: parsedCreatedAt,
    note: typeof note === "string" && note.trim() !== "" ? note.trim() : undefined,
  };
}

function parseFromKeyValue(payload: string): PassphraseEncryptedVault {
  const lines = payload
    .split(/\r?\n/)
    .map((line) => line.trim())
    .filter((line) => line.length > 0);

  const kv: Record<string, string> = {};
  for (const line of lines) {
    const idx = line.indexOf(":");
    if (idx === -1) {
      continue;
    }
    const key = line.slice(0, idx).trim().toLowerCase();
    const value = line.slice(idx + 1).trim();
    if (key.length > 0 && value.length > 0) {
      kv[key] = value;
    }
  }

  const ciphertext = kv["ciphertext"];
  const salt = kv["salt"];
  const iv = kv["iv"];

  if (!ciphertext || !salt || !iv) {
    throw new Error(
      "Unable to parse encrypted payload. Ensure you pasted the JSON file or the full message."
    );
  }

  const parsedIterations = kv["iterations"] ? Number(kv["iterations"]) : PBKDF2_ITERATIONS;
  const parsedCreatedAt = kv["created"]
    ? Date.parse(kv["created"])
    : Number.isFinite(Number(kv["created"]))
    ? Number(kv["created"])
    : Date.now();

  return {
    ciphertext,
    salt,
    iv,
    version: kv["version"] || VERSION,
    algorithm: kv["algorithm"] || ALGORITHM,
    iterations: Number.isFinite(parsedIterations) ? parsedIterations : PBKDF2_ITERATIONS,
    createdAt: Number.isFinite(parsedCreatedAt) ? parsedCreatedAt : Date.now(),
    note: kv["note"],
  };
}

export function parseEncryptedVaultPayload(payload: string): PassphraseEncryptedVault {
  const trimmed = payload.trim();
  if (!trimmed) {
    throw new Error("Encrypted payload cannot be empty.");
  }

  try {
    const parsed = JSON.parse(trimmed);
    return normaliseVaultFromJson(parsed);
  } catch (_error) {
    return normaliseVaultFromJson(parseFromKeyValue(trimmed));
  }
}

export function formatVaultFilename(createdAt: number = Date.now()): string {
  const timestamp = new Date(createdAt)
    .toISOString()
    .replace(/[:.]/g, "-");
  return `${DEFAULT_FILENAME_PREFIX}-${timestamp}.json`;
}

export function downloadEncryptedVault(
  vault: PassphraseEncryptedVault,
  filename = formatVaultFilename(vault.createdAt)
) {
  if (typeof document === "undefined") {
    throw new Error("File download is only supported in browser environments.");
  }

  const payload = serializeEncryptedVault(vault, true);
  const blob = new Blob([payload], { type: "application/json" });
  const url = URL.createObjectURL(blob);
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  document.body.appendChild(anchor);
  anchor.click();
  document.body.removeChild(anchor);
  setTimeout(() => URL.revokeObjectURL(url), 1_000);
}

