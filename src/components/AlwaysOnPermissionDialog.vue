<template>
  <q-dialog v-model="show" persistent>
    <q-card style="min-width: 400px">
      <q-card-section class="row items-center">
        <q-icon name="battery_charging_full" color="primary" size="md" class="q-mr-sm" />
        <span class="text-h6">Battery Optimization</span>
      </q-card-section>

      <q-card-section>
        <div class="text-body1 q-mb-md">
          To keep Bitpoints running 24/7, we need to disable battery optimization for this app.
        </div>
        
        <div class="text-body2 text-grey-7 q-mb-md">
          <strong>Why this is needed:</strong>
          <ul class="q-mt-sm">
            <li>Receive tokens even when screen is off</li>
            <li>Keep Bluetooth mesh active for offline transfers</li>
            <li>Act as relay node for other devices</li>
          </ul>
        </div>

        <q-banner dense class="bg-info text-white q-mb-md" rounded>
          <template v-slot:avatar>
            <q-icon name="info" />
          </template>
          This will use more battery but ensures you never miss incoming tokens.
        </q-banner>
      </q-card-section>

      <q-card-actions align="right" class="q-pa-md">
        <q-btn flat label="Cancel" color="grey" @click="onCancel" />
        <q-btn 
          color="primary" 
          label="Open Settings" 
          @click="onAllow"
          :loading="loading"
        />
      </q-card-actions>
    </q-card>
  </q-dialog>
</template>

<script setup lang="ts">
import { ref, computed } from 'vue';
import { useBluetoothStore } from 'src/stores/bluetooth';
import { notifySuccess, notifyError } from 'src/js/notify';

interface Props {
  modelValue: boolean;
}

interface Emits {
  (e: 'update:modelValue', value: boolean): void;
}

const props = defineProps<Props>();
const emit = defineEmits<Emits>();

const bluetoothStore = useBluetoothStore();
const loading = ref(false);

const show = computed({
  get: () => props.modelValue,
  set: (value) => emit('update:modelValue', value)
});

async function onAllow() {
  loading.value = true;
  
  try {
    await bluetoothStore.requestBatteryOptimizationExemption();
    show.value = false;
    notifySuccess('Battery optimization settings opened. Please allow Bitpoints to run in background.');
  } catch (error) {
    console.error('Failed to open battery settings:', error);
    notifyError('Failed to open battery settings. Please enable manually in Android Settings.');
  } finally {
    loading.value = false;
  }
}

function onCancel() {
  show.value = false;
}
</script>

<style scoped>
.q-card {
  max-width: 500px;
}
</style>
