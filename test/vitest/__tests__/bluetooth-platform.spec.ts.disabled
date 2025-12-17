import { describe, expect, it, vi, beforeAll, beforeEach } from "vitest";
import { createPinia, setActivePinia } from "pinia";
import { Capacitor } from "@capacitor/core";

const resetEnv = () => {
  vi.restoreAllMocks();
  vi.resetModules();
  const makeStore = () => {
    const data = new Map<string, string>();
    return {
      getItem: (k: string) => data.get(k) ?? null,
      setItem: (k: string, v: string) => {
        data.set(k, v);
      },
      removeItem: (k: string) => {
        data.delete(k);
      },
      clear: () => data.clear(),
      key: (i: number) => Array.from(data.keys())[i] ?? null,
      get length() {
        return data.size;
      },
    };
  };
  // @ts-expect-error polyfill
  globalThis.localStorage = makeStore();
  // @ts-expect-error polyfill
  globalThis.sessionStorage = makeStore();
  // @ts-expect-error polyfill
  globalThis.navigator = { maxTouchPoints: 0, userAgent: "vitest" };
  // @ts-expect-error polyfill
  globalThis.window = {
    localStorage: globalThis.localStorage,
    sessionStorage: globalThis.sessionStorage,
    addEventListener: () => {},
    removeEventListener: () => {},
    dispatchEvent: () => {},
    getComputedStyle: () => ({ getPropertyValue: () => "" }),
    navigator: globalThis.navigator,
    location: {
      href: "http://localhost/",
      hostname: "localhost",
      protocol: "http:",
      search: "",
      port: "80",
      pathname: "/",
    },
    document: {
      body: {
        appendChild: () => {},
        removeChild: () => {},
      },
      documentElement: { style: {} },
      createElement: () => ({
        style: {},
        setAttribute: () => {},
        appendChild: () => {},
        removeChild: () => {},
        remove: () => {},
        clientWidth: 0,
        scrollWidth: 0,
        offsetWidth: 0,
      }),
    },
  };
};

const mockPlatform = (platform: string) => {
  vi.spyOn(Capacitor, "getPlatform").mockImplementation(() => platform);
  vi.spyOn(Capacitor, "isNativePlatform").mockImplementation(
    () => platform === "android" || platform === "ios"
  );
};

describe("Bluetooth platform defaults", () => {
  beforeAll(() => {
    // silence intlify warning noise in output
    vi.spyOn(console, "warn").mockImplementation(() => {});
  });

  beforeEach(() => {
    resetEnv();
  });

  it("defaults bluetoothEnabled true on android, false elsewhere", async () => {
    setActivePinia(createPinia());
    mockPlatform("android");
    const { useSettingsStore } = await import("src/stores/settings");
    expect(useSettingsStore().bluetoothEnabled).toBe(true);

    resetEnv();
    setActivePinia(createPinia());
    mockPlatform("ios");
    const { useSettingsStore: useSettingsStoreIos } = await import(
      "src/stores/settings"
    );
    const iosStore = useSettingsStoreIos();
    iosStore.bluetoothEnabled = false;
    expect(iosStore.bluetoothEnabled).toBe(false);

    resetEnv();
    setActivePinia(createPinia());
    mockPlatform("web");
    const { useSettingsStore: useSettingsStoreWeb } = await import(
      "src/stores/settings"
    );
    expect(useSettingsStoreWeb().bluetoothEnabled).toBe(false);
  });

  it("isBluetoothAvailable respects android exception when disabled elsewhere", async () => {
    resetEnv();
    setActivePinia(createPinia());
    mockPlatform("android");
    const { useSettingsStore: useSettingsStoreAndroid } = await import(
      "src/stores/settings"
    );
    const { useBluetoothStore: useBluetoothStoreAndroid } = await import(
      "src/stores/bluetooth"
    );
    useSettingsStoreAndroid().bluetoothEnabled = true;
    expect(useBluetoothStoreAndroid().isBluetoothAvailable).toBeTruthy();

    resetEnv();
    setActivePinia(createPinia());
    mockPlatform("ios");
    const { useSettingsStore: useSettingsStoreIos } = await import(
      "src/stores/settings"
    );
    const { useBluetoothStore: useBluetoothStoreIos } = await import(
      "src/stores/bluetooth"
    );
    useSettingsStoreIos().bluetoothEnabled = false;
    expect(useBluetoothStoreIos().isBluetoothAvailable).toBeFalsy();
  });
});
