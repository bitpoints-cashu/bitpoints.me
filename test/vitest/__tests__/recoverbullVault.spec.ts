import { describe, expect, it } from "vitest";
import { webcrypto } from "crypto";
import {
  ARGON2_KEY_BYTES,
  bytesToHex,
  computePasswordKeys,
  createRecoverbullBackup,
  decodeEnvelope,
  parseBullBackup,
  restoreRecoverbullBackup,
} from "src/utils/recoverbullVault";

if (typeof (globalThis as any).crypto === "undefined") {
  (globalThis as any).crypto = webcrypto as unknown as Crypto;
}

const mnemonic12 = [
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "abandon",
  "about",
];

function createDeterministicRandom() {
  let counter = 0;
  return (length: number) => {
    const buffer = new Uint8Array(length);
    for (let i = 0; i < length; i++) {
      buffer[i] = counter & 0xff;
      counter = (counter + 1) & 0xff;
    }
    return buffer;
  };
}

describe("recoverbullVault cryptography", () => {
  it("creates and restores a RecoverBull backup deterministically", async () => {
    const deterministicRandom = createDeterministicRandom();
    const fixedSalt = Uint8Array.from({ length: 16 }, (_, i) => i + 1);
    const createdAt = 1_700_000_000_000;

    const { backup, backupKeyHex, derivationPath } =
      await createRecoverbullBackup(mnemonic12, {
        randomBytes: deterministicRandom,
        salt: fixedSalt,
        createdAt,
      });

    expect(backup.created_at).toBe(createdAt);
    expect(backup.path).toBe("1608'/0'/50462976'");
    expect(backup.id).toHaveLength(64);
    expect(backup.salt).toBe(bytesToHex(fixedSalt));
    expect(backup.ciphertext.length).toBeGreaterThan(0);
    expect(backupKeyHex).toHaveLength(ARGON2_KEY_BYTES * 2);
    expect(derivationPath).toBe("1608'/0'/50462976'");

    const parsed = parseBullBackup(backup);
    expect(Array.from(parsed.id.slice(0, 8))).toEqual([20, 21, 22, 23, 24, 25, 26, 27]);
    expect(parsed.salt).toEqual(fixedSalt);

    const envelope = decodeEnvelope(parsed.ciphertext);
    expect(Array.from(envelope.nonce)).toEqual(
      Array.from({ length: 16 }, (_, i) => i + 4)
    );
    expect(envelope.ciphertext.length).toBeGreaterThan(0);
    expect(envelope.hmac.length).toBe(32);

    const restored = await restoreRecoverbullBackup(backup, backupKeyHex);
    expect(restored.mnemonic).toEqual(mnemonic12);
    expect(restored.createdAt).toBe(createdAt);
    expect(restored.version).toBe("1.0");
  });

  it("derives password keys matching RecoverBull parameters", () => {
    const salt = Uint8Array.from({ length: 16 }, (_, i) => i + 1);
    const password = "correct horse battery staple";
    const keys = computePasswordKeys(password, salt);

    expect(bytesToHex(keys.authenticationKey)).toBe(
      "15f27b3c958c09691754a9aed801aedb15cd20fb6361905638bc9801af42f44d"
    );
    expect(bytesToHex(keys.encryptionKey)).toBe(
      "0b5e6f49ca002a0eaced34380987398c594436db90784532f5ca1cb64802556a"
    );
  });
});


