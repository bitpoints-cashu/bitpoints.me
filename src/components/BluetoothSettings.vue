<template>
  <q-card flat bordered>
    <q-card-section>
      <div class="text-h6">
        <q-icon name="bluetooth" class="q-mr-sm" />
        Bluetooth Settings
      </div>
      <div class="text-caption text-grey-6">
        Configure your Bluetooth mesh networking
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section>
      <q-input
        v-model="localNickname"
        label="Bluetooth Name"
        hint="How you appear to nearby peers"
        outlined
        :rules="[
          val => val && val.length >= 3 || 'Minimum 3 characters',
          val => val && val.length <= 32 || 'Maximum 32 characters'
        ]"
      >
        <template #prepend>
          <q-icon name="person" />
        </template>
        <template #append>
          <q-btn
            v-if="nicknameChanged"
            flat
            dense
            round
            icon="check"
            color="primary"
            @click="saveNickname"
          >
            <q-tooltip>Apply changes</q-tooltip>
          </q-btn>
        </template>
      </q-input>

      <div class="text-caption text-grey-6 q-mt-xs">
        Current: <strong>{{ bluetoothStore.nickname }}</strong>
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section>
      <div class="text-subtitle2 q-mb-sm">Connection Status</div>

      <!-- Desktop help text -->
      <q-banner v-if="isDesktop && !bluetoothStore.isActive" dense class="bg-info text-white q-mb-sm" rounded>
        <template v-slot:avatar>
          <q-icon name="info" />
        </template>
        Click "Connect Device" to enable Bluetooth. Your browser will show available devices.
      </q-banner>

      <q-list dense>
        <q-item>
          <q-item-section avatar>
            <q-icon
              :name="bluetoothStore.isActive ? 'bluetooth_connected' : 'bluetooth_disabled'"
              :color="bluetoothStore.isActive ? 'positive' : 'grey'"
            />
          </q-item-section>
          <q-item-section>
            <q-item-label>Bluetooth Mesh</q-item-label>
            <q-item-label caption>
              {{ bluetoothStore.isActive ? 'Active' : 'Disabled' }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <!-- Desktop: Show button to connect to device -->
            <q-btn
              v-if="isDesktop && !bluetoothStore.isActive"
              outline
              color="primary"
              size="sm"
              icon="bluetooth_searching"
              label="Connect Device"
              @click="connectDesktopDevice"
              :disable="!isWebBluetoothSupported"
            >
              <q-tooltip v-if="!isWebBluetoothSupported">
                Web Bluetooth not supported in this browser. Try Chrome or Edge.
              </q-tooltip>
            </q-btn>
            <!-- Desktop: Show disconnect button when active -->
            <q-btn
              v-else-if="isDesktop && bluetoothStore.isActive"
              flat
              color="negative"
              size="sm"
              icon="bluetooth_disabled"
              label="Disconnect"
              @click="toggleBluetooth(false)"
            />
            <!-- Mobile: Show toggle -->
            <q-toggle
              v-else
              :model-value="bluetoothStore.isActive"
              @update:model-value="toggleBluetooth"
              color="primary"
            />
          </q-item-section>
        </q-item>

        <q-item clickable v-ripple @click="openNearbyDialog">
          <q-item-section avatar>
            <q-icon name="people" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Nearby Peers</q-item-label>
            <q-item-label caption>
              {{ bluetoothStore.nearbyPeers.length }} discovered
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-icon name="chevron_right" color="grey" />
          </q-item-section>
        </q-item>

        <q-item v-if="favoritesStore.mutualCount > 0">
          <q-item-section avatar>
            <q-icon name="favorite" color="pink" />
          </q-item-section>
          <q-item-section>
            <q-item-label>Mutual Favorites</q-item-label>
            <q-item-label caption>
              {{ favoritesStore.mutualCount }} contacts
            </q-item-label>
          </q-item-section>
        </q-item>
      </q-list>
    </q-card-section>

    <q-separator />

    <!-- Always-On Mode Section (Android only) -->
    <q-card-section v-if="!isDesktop">
      <div class="text-subtitle2 q-mb-sm">Always-On Mode</div>
      <div class="text-caption text-grey-6 q-mb-sm">
        For kids' devices without consistent internet - keeps Bluetooth mesh active 24/7
      </div>

      <q-list dense>
        <q-item>
          <q-item-section avatar>
            <q-icon
              :name="bluetoothStore.alwaysOnActive ? 'battery_charging_full' : 'battery_std'"
              :color="bluetoothStore.alwaysOnActive ? 'positive' : 'grey'"
            />
          </q-item-section>
          <q-item-section>
            <q-item-label>Always Keep Running</q-item-label>
            <q-item-label caption>
              {{ bluetoothStore.alwaysOnActive ? 'Active - Bluetooth mesh stays on 24/7' : 'Inactive - Normal battery usage' }}
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-toggle
              :model-value="bluetoothStore.alwaysOnEnabled"
              @update:model-value="toggleAlwaysOnMode"
              color="primary"
              :disable="!bluetoothStore.isActive"
            />
          </q-item-section>
        </q-item>
      </q-list>

      <div class="q-mt-sm">
        <q-btn
          v-if="bluetoothStore.alwaysOnEnabled"
          flat
          dense
          size="sm"
          color="primary"
          icon="settings"
          label="Battery Settings"
          @click="requestBatteryOptimization"
        />
      </div>

      <!-- Warning banner -->
      <q-banner
        v-if="bluetoothStore.alwaysOnEnabled"
        dense
        class="bg-warning text-dark q-mt-sm"
        rounded
      >
        <template v-slot:avatar>
          <q-icon name="battery_alert" />
        </template>
        <strong>Battery Usage:</strong> Always-on mode uses more battery but ensures you can receive tokens anytime.
        <template v-slot:action>
          <q-btn flat dense size="sm" label="Learn More" @click="showBatteryInfo" />
        </template>
      </q-banner>
    </q-card-section>

    <q-separator />

    <q-card-section>
      <div class="row q-gutter-sm">
        <q-btn
          outline
          color="primary"
          icon="people"
          label="Nearby Contacts"
          @click="showNearbyContacts"
        />
        <q-btn
          v-if="favoritesStore.mutualCount > 0"
          outline
          color="pink"
          icon="favorite"
          label="Favorites"
          @click="showFavorites"
        >
          <q-badge v-if="favoritesStore.pendingCount > 0" color="red" floating>
            {{ favoritesStore.pendingCount }}
          </q-badge>
        </q-btn>
        <q-btn
          v-if="favoritesStore.pendingCount > 0"
          rounded
          outline
          color="orange"
          icon="inbox"
          label="Requests"
          @click="showRequests"
        >
          <q-badge color="red" floating>
            {{ favoritesStore.pendingCount }}
          </q-badge>
        </q-btn>
      </div>
    </q-card-section>

    <q-separator />

    <q-card-section class="q-pt-sm">
      <div class="text-caption text-grey-6">
        <q-icon name="info" size="xs" class="q-mr-xs" />
        <span v-if="isDesktop && !isWebBluetoothSupported">
          ⚠️ Web Bluetooth not available. Please use <strong>Chrome</strong> or <strong>Edge</strong> browser.
        </span>
        <span v-else-if="isDesktop">
          💡 Click "Enable" to connect to a nearby Bluetooth device. The browser will show a device picker.
        </span>
        <span v-else>
          Bluetooth mesh enables offline token transfers
        </span>
      </div>
    </q-card-section>
  </q-card>
</template>

<script setup lang="ts">
import { ref, computed, onMounted } from 'vue';
import { useBluetoothStore } from 'src/stores/bluetooth';
import { useFavoritesStore } from 'src/stores/favorites';
import { Capacitor } from '@capacitor/core';
import { notifySuccess } from 'src/js/notify';

const emit = defineEmits<{
  (e: 'openNearbyDialog'): void;
  (e: 'openContactsDialog'): void;
  (e: 'openRequestsDialog'): void;
}>();

const bluetoothStore = useBluetoothStore();
const favoritesStore = useFavoritesStore();

const localNickname = ref('');
const isDesktop = computed(() => !Capacitor.isNativePlatform());

const isWebBluetoothSupported = computed(() => {
  try {
    return typeof navigator !== 'undefined' && 'bluetooth' in navigator;
  } catch (error) {
    console.error('Error checking Web Bluetooth support:', error);
    return false;
  }
});

const nicknameChanged = computed(() => {
  return localNickname.value !== bluetoothStore.nickname;
});

async function saveNickname() {
  if (!localNickname.value || localNickname.value.length < 3) {
    return;
  }

  try {
    // Update nickname in store
    await bluetoothStore.updateNickname(localNickname.value);
    notifySuccess('Bluetooth name updated!');
  } catch (error) {
    console.error('Failed to update nickname:', error);
  }
}

async function toggleBluetooth(enabled: boolean) {
  if (enabled) {
    await bluetoothStore.startService();
  } else {
    await bluetoothStore.stopService();
  }
}

async function connectDesktopDevice() {
  try {
    // For desktop, this will show the browser's device picker
    await bluetoothStore.startService();
  } catch (error) {
    console.error('Failed to connect to Bluetooth device:', error);
  }
}

function openNearbyDialog() {
  emit('openNearbyDialog');
}

function showNearbyContacts() {
  emit('openNearbyDialog');
}

function showFavorites() {
  emit('openContactsDialog');
}

function showRequests() {
  emit('openRequestsDialog');
}

async function toggleAlwaysOnMode(enabled: boolean) {
  try {
    await bluetoothStore.toggleAlwaysOnMode(enabled);
  } catch (error) {
    console.error('Failed to toggle always-on mode:', error);
  }
}

async function requestBatteryOptimization() {
  try {
    await bluetoothStore.requestBatteryOptimizationExemption();
  } catch (error) {
    console.error('Failed to request battery optimization exemption:', error);
  }
}

function showBatteryInfo() {
  // Show info about battery usage
  console.log('Show battery usage information');
  // TODO: Implement battery info dialog
}

onMounted(async () => {
  localNickname.value = bluetoothStore.nickname;

  // Check always-on status on mount
  if (!isDesktop.value) {
    await bluetoothStore.checkAlwaysOnStatus();
  }
});
</script>

<style scoped lang="scss">
.q-card {
  max-width: 600px;
}
</style>

