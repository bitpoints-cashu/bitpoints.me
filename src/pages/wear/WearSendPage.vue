<template>
  <q-page class="wear-send-page">
    <!-- Header -->
    <div class="bitpoints-header">
      <h2>Send Tokens</h2>
      <q-btn flat round icon="arrow_back" @click="goBack" class="back-btn" />
    </div>

    <!-- Amount Input -->
    <div class="amount-section">
      <q-input
        v-model="sendAmount"
        type="number"
        label="Amount (sats)"
        outlined
        :rules="[(val) => val > 0 || 'Enter amount']"
        class="amount-input"
      />
    </div>

    <!-- Nearby Peers -->
    <div class="peers-section">
      <h4>Nearby Devices</h4>

      <div v-if="isScanning" class="scanning-indicator">
        <q-spinner size="20px" />
        <span>Scanning for devices...</span>
      </div>

      <div v-else-if="nearbyPeers.length === 0" class="no-peers">
        <q-icon name="bluetooth_disabled" size="32px" />
        <p>No devices found</p>
        <q-btn color="primary" @click="startScanning" :loading="isScanning">
          Scan Again
        </q-btn>
      </div>

      <div v-else class="peers-list">
        <div
          v-for="peer in nearbyPeers"
          :key="peer.id"
          class="peer-item"
          @click="selectPeer(peer)"
          :class="{ selected: selectedPeer?.id === peer.id }"
        >
          <div class="peer-info">
            <div class="peer-name">{{ peer.name || "Unknown Device" }}</div>
            <div class="peer-status">
              <span class="status-indicator status-connected"></span>
              {{ peer.rssi }} dBm
            </div>
          </div>
          <q-icon name="chevron_right" />
        </div>
      </div>
    </div>

    <!-- Send Button -->
    <div class="send-section" v-if="selectedPeer && sendAmount > 0">
      <q-btn
        class="send-btn"
        color="primary"
        size="lg"
        @click="sendTokens"
        :loading="isSending"
        :disable="!canSend"
      >
        <q-icon name="send" />
        <span>Send {{ formatAmount(sendAmount) }} sats</span>
      </q-btn>

      <div class="send-to">to {{ selectedPeer.name || "Unknown Device" }}</div>
    </div>

    <!-- Status Messages -->
    <div v-if="statusMessage" class="status-message" :class="statusType">
      <q-icon :name="statusIcon" />
      <span>{{ statusMessage }}</span>
    </div>
  </q-page>
</template>

<script setup lang="js">
import { ref, computed, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { useWalletStore } from "src/stores/wallet";
import { useBluetoothStore } from "src/stores/bluetooth";
import { Notify } from "quasar";

const router = useRouter();
const walletStore = useWalletStore();
const bluetoothStore = useBluetoothStore();

// Reactive data
const sendAmount = ref(0);
const selectedPeer = ref(null);
const isScanning = ref(false);
const isSending = ref(false);
const statusMessage = ref("");
const statusType = ref("info");
const nearbyPeers = ref([]);

// Computed properties
const canSend = computed(() => {
  return (
    selectedPeer.value &&
    sendAmount.value > 0 &&
    sendAmount.value <= walletStore.totalBalance &&
    !isSending.value
  );
});

const statusIcon = computed(() => {
  switch (statusType.value) {
    case "success":
      return "check_circle";
    case "error":
      return "error";
    case "warning":
      return "warning";
    default:
      return "info";
  }
});

// Methods
const formatAmount = (amount) => {
  return new Intl.NumberFormat().format(amount);
};

const goBack = () => {
  router.push("/wear/wallet");
};

const startScanning = async () => {
  isScanning.value = true;
  statusMessage.value = "Scanning for nearby devices...";
  statusType.value = "info";

  try {
    await bluetoothStore.startScanning();
    nearbyPeers.value = bluetoothStore.discoveredPeers;
  } catch (error) {
    statusMessage.value = "Failed to start scanning";
    statusType.value = "error";
    console.error("Scanning error:", error);
  } finally {
    isScanning.value = false;
  }
};

const selectPeer = (peer) => {
  selectedPeer.value = peer;
  statusMessage.value = `Selected: ${peer.name || "Unknown Device"}`;
  statusType.value = "info";
};

const sendTokens = async () => {
  if (!canSend.value) return;

  isSending.value = true;
  statusMessage.value = "Sending tokens...";
  statusType.value = "info";

  try {
    // Create ecash tokens
    const tokens = await walletStore.createTokens(sendAmount.value);

    // Send via Bluetooth mesh
    await bluetoothStore.sendTokens(selectedPeer.value.id, tokens);

    statusMessage.value = "Tokens sent successfully!";
    statusType.value = "success";

    // Show notification
    Notify.create({
      type: "positive",
      message: `Sent ${formatAmount(sendAmount.value)} sats`,
      position: "top",
    });

    // Reset form
    setTimeout(() => {
      sendAmount.value = 0;
      selectedPeer.value = null;
      statusMessage.value = "";
      goBack();
    }, 2000);
  } catch (error) {
    statusMessage.value = "Failed to send tokens";
    statusType.value = "error";
    console.error("Send error:", error);
  } finally {
    isSending.value = false;
  }
};

// Lifecycle
onMounted(() => {
  startScanning();
});

onUnmounted(() => {
  bluetoothStore.stopScanning();
});
</script>

<style scoped>
.wear-send-page {
  padding: 8px;
}

.bitpoints-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
}

.back-btn {
  position: absolute;
  left: 8px;
  top: 8px;
}

.amount-section {
  margin: 16px 0;
}

.amount-input {
  font-size: 18px;
}

.peers-section {
  margin: 20px 0;
}

.peers-section h4 {
  text-align: center;
  margin-bottom: 12px;
  font-size: 16px;
}

.scanning-indicator {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 20px;
  color: #ff9800;
}

.no-peers {
  text-align: center;
  padding: 20px;
  color: #666;
}

.no-peers p {
  margin: 8px 0;
}

.peers-list {
  max-height: 200px;
  overflow-y: auto;
}

.peer-item {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding: 12px;
  margin: 4px 0;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  cursor: pointer;
  transition: all 0.2s;
}

.peer-item:hover {
  background: rgba(255, 255, 255, 0.1);
}

.peer-item.selected {
  background: rgba(25, 118, 210, 0.2);
  border-color: #1976d2;
}

.peer-info {
  flex: 1;
}

.peer-name {
  font-size: 16px;
  font-weight: 500;
  margin-bottom: 2px;
}

.peer-status {
  font-size: 12px;
  opacity: 0.7;
  display: flex;
  align-items: center;
  gap: 4px;
}

.send-section {
  margin: 20px 0;
  text-align: center;
}

.send-btn {
  width: 100%;
  min-height: 56px;
  font-size: 16px;
  font-weight: 500;
}

.send-to {
  margin-top: 8px;
  font-size: 12px;
  opacity: 0.7;
}

.status-message {
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 8px;
  padding: 12px;
  margin: 16px 0;
  border-radius: 8px;
  font-size: 14px;
}

.status-message.success {
  background: rgba(76, 175, 80, 0.2);
  color: #4caf50;
}

.status-message.error {
  background: rgba(244, 67, 54, 0.2);
  color: #f44336;
}

.status-message.warning {
  background: rgba(255, 152, 0, 0.2);
  color: #ff9800;
}

.status-message.info {
  background: rgba(33, 150, 243, 0.2);
  color: #2196f3;
}

/* Wear OS specific adjustments */
@media screen and (max-width: 400px) {
  .amount-input {
    font-size: 16px;
  }

  .peer-item {
    padding: 10px;
  }

  .peer-name {
    font-size: 14px;
  }

  .send-btn {
    min-height: 48px;
    font-size: 14px;
  }
}
</style>
