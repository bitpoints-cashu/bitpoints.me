import { beforeEach, describe, expect, it, vi } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { webcrypto } from "crypto";
import { useRecoverbullBackupStore } from "src/stores/recoverbullBackup";
import { useRecoverbullKeyServerStore } from "src/stores/recoverbullKeyServer";

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

describe("RecoverBull backup store", () => {
  beforeEach(() => {
    setActivePinia(createPinia());
  });

  it("creates and restores a RecoverBull backup through the key server store", async () => {
    const backupStore = useRecoverbullBackupStore();
    const keyServerStore = useRecoverbullKeyServerStore();

    const captures: {
      storedPayload?: Parameters<typeof keyServerStore.storeBackupKey>[0];
    } = {};

    keyServerStore.storeBackupKey = vi
      .fn(async (payload) => {
        captures.storedPayload = payload;
      })
      .mockName("storeBackupKey") as any;

    keyServerStore.fetchBackupKey = vi
      .fn(async ({ identifier, password, salt }) => {
        expect(password).toBe("strongpassword");
        expect(captures.storedPayload).toBeDefined();
        expect(Array.from(identifier)).toEqual(
          Array.from(captures.storedPayload!.identifier)
        );
        expect(Array.from(salt)).toEqual(Array.from(captures.storedPayload!.salt));
        return captures.storedPayload!.backupKey;
      })
      .mockName("fetchBackupKey") as any;

    const summary = await backupStore.createBackup({
      mnemonic: mnemonic12,
      password: "strongpassword",
    });

    expect(summary).toBeTruthy();
    expect(summary.backupJson).toContain('"ciphertext"');
    expect(captures.storedPayload).toBeDefined();
    expect(keyServerStore.storeBackupKey).toHaveBeenCalledTimes(1);

    const restored = await backupStore.restoreBackup({
      backupJson: summary.backupJson,
      password: "strongpassword",
    });

    expect(restored).toEqual(mnemonic12);
    expect(keyServerStore.fetchBackupKey).toHaveBeenCalledTimes(1);
  });
});


