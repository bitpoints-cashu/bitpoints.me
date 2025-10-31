<template>
  <q-page class="wear-receive-page">
    <!-- Header -->
    <div class="bitpoints-header">
      <h2>Receive Tokens</h2>
      <q-btn flat round icon="arrow_back" @click="goBack" class="back-btn" />
    </div>

    <!-- QR Code Display -->
    <div class="qrcode-section">
      <div class="qrcode-container">
        <div v-if="!isGenerating" class="qrcode-wrapper">
          <canvas ref="qrCanvas" class="qrcode-canvas"></canvas>
        </div>
        <div v-else class="qrcode-loading">
          <q-spinner size="32px" />
          <p>Generating QR code...</p>
        </div>
      </div>

      <div class="qrcode-info">
        <p>Show this QR code to receive tokens</p>
        <p class="amount-info">{{ formatAmount(receiveAmount) }} sats</p>
      </div>
    </div>

    <!-- Amount Selection -->
    <div class="amount-section">
      <h4>Receive Amount</h4>
      <div class="amount-buttons">
        <q-btn
          v-for="amount in quickAmounts"
          :key="amount"
          :label="formatAmount(amount)"
          :color="receiveAmount === amount ? 'primary' : 'secondary'"
          @click="setReceiveAmount(amount)"
          class="amount-btn"
        />
      </div>

      <q-input
        v-model="customAmount"
        type="number"
        label="Custom amount (sats)"
        outlined
        @update:model-value="setCustomAmount"
        class="custom-amount-input"
      />
    </div>

    <!-- NFC Option -->
    <div class="nfc-section" v-if="hasNFC">
      <q-btn
        color="accent"
        @click="enableNFC"
        :loading="isEnablingNFC"
        class="nfc-btn"
      >
        <q-icon name="nfc" />
        <span>Enable NFC</span>
      </q-btn>
      <p class="nfc-info">Tap devices together to transfer</p>
    </div>

    <!-- Status -->
    <div class="status-section">
      <div class="status-item">
        <span class="status-indicator" :class="bluetoothStatusClass"></span>
        <span>{{ bluetoothStatusText }}</span>
      </div>

      <div v-if="pendingReceives.length > 0" class="pending-receives">
        <h5>Pending Receives</h5>
        <div
          v-for="receive in pendingReceives"
          :key="receive.id"
          class="pending-item"
        >
          <div class="pending-amount">
            {{ formatAmount(receive.amount) }} sats
          </div>
          <div class="pending-time">{{ formatTime(receive.timestamp) }}</div>
        </div>
      </div>
    </div>

    <!-- Instructions -->
    <div class="instructions">
      <h5>How to receive:</h5>
      <ol>
        <li>Show QR code to sender</li>
        <li>Or enable NFC and tap devices</li>
        <li>Or share via Nostr message</li>
      </ol>
    </div>
  </q-page>
</template>

<script setup lang="js">
import { ref, computed, onMounted, onUnmounted, nextTick } from "vue";
import { useRouter } from "vue-router";
import { useWalletStore } from "src/stores/wallet";
import { useBluetoothStore } from "src/stores/bluetooth";
import QRCode from "qrcode";

const router = useRouter();
const walletStore = useWalletStore();
const bluetoothStore = useBluetoothStore();

// Reactive data
const qrCanvas = ref(null);
const receiveAmount = ref(1000);
const customAmount = ref("");
const isGenerating = ref(false);
const isEnablingNFC = ref(false);
const hasNFC = ref(false);
const pendingReceives = ref([]);

// Quick amount options
const quickAmounts = ref([100, 500, 1000, 5000, 10000]);

// Computed properties
const bluetoothStatusClass = computed(() => {
  if (bluetoothStore.isConnected) return "status-connected";
  return "status-disconnected";
});

const bluetoothStatusText = computed(() => {
  return bluetoothStore.isConnected ? "Ready to receive" : "Bluetooth offline";
});

// Methods
const formatAmount = (amount) => {
  return new Intl.NumberFormat().format(amount);
};

const formatTime = (timestamp) => {
  return new Date(timestamp).toLocaleTimeString();
};

const goBack = () => {
  router.push("/wear/wallet");
};

const setReceiveAmount = (amount) => {
  receiveAmount.value = amount;
  customAmount.value = "";
  generateQRCode();
};

const setCustomAmount = (value) => {
  if (value && !isNaN(value) && value > 0) {
    receiveAmount.value = parseInt(value);
    generateQRCode();
  }
};

const generateQRCode = async () => {
  if (!qrCanvas.value) return;

  isGenerating.value = true;

  try {
    // Create receive request
    const receiveRequest = {
      amount: receiveAmount.value,
      mint: walletStore.defaultMint,
      timestamp: Date.now(),
      type: "receive_request",
    };

    const qrData = JSON.stringify(receiveRequest);

    // Generate QR code
    await QRCode.toCanvas(qrCanvas.value, qrData, {
      width: 200,
      height: 200,
      margin: 2,
      color: {
        dark: "#000000",
        light: "#FFFFFF",
      },
    });
  } catch (error) {
    console.error("QR code generation error:", error);
  } finally {
    isGenerating.value = false;
  }
};

const enableNFC = async () => {
  isEnablingNFC.value = true;

  try {
    // Enable NFC for token transfer
    // Implementation depends on NFC API availability
    await new Promise((resolve) => setTimeout(resolve, 1000)); // Simulate

    // Show success message
    console.log("NFC enabled for token transfer");
  } catch (error) {
    console.error("NFC enable error:", error);
  } finally {
    isEnablingNFC.value = false;
  }
};

const checkNFC = () => {
  // Check if device has NFC capability
  hasNFC.value = "nfc" in navigator || false;
};

const loadPendingReceives = () => {
  // Load pending receive requests
  pendingReceives.value = walletStore.pendingReceives || [];
};

// Lifecycle
onMounted(async () => {
  checkNFC();
  loadPendingReceives();

  await nextTick();
  generateQRCode();
});

onUnmounted(() => {
  // Cleanup if needed
});
</script>

<style scoped>
.wear-receive-page {
  padding: 8px;
  text-align: center;
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

.qrcode-section {
  margin: 20px 0;
}

.qrcode-container {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 12px;
}

.qrcode-wrapper {
  padding: 16px;
  background: white;
  border-radius: 12px;
  box-shadow: 0 4px 8px rgba(0, 0, 0, 0.3);
}

.qrcode-canvas {
  max-width: 200px;
  max-height: 200px;
  width: auto;
  height: auto;
}

.qrcode-loading {
  display: flex;
  flex-direction: column;
  align-items: center;
  gap: 8px;
  padding: 20px;
  color: #666;
}

.qrcode-info {
  margin-top: 8px;
}

.qrcode-info p {
  margin: 4px 0;
  font-size: 14px;
}

.amount-info {
  font-size: 18px !important;
  font-weight: bold !important;
  color: #4caf50 !important;
}

.amount-section {
  margin: 20px 0;
}

.amount-section h4 {
  margin-bottom: 12px;
  font-size: 16px;
}

.amount-buttons {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  justify-content: center;
  margin-bottom: 12px;
}

.amount-btn {
  min-width: 60px;
  min-height: 40px;
  font-size: 12px;
}

.custom-amount-input {
  margin-top: 8px;
}

.nfc-section {
  margin: 20px 0;
}

.nfc-btn {
  width: 100%;
  min-height: 48px;
  margin-bottom: 8px;
}

.nfc-info {
  font-size: 12px;
  opacity: 0.7;
  margin: 0;
}

.status-section {
  margin: 20px 0;
}

.status-item {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 4px 0;
  font-size: 12px;
}

.pending-receives {
  margin-top: 16px;
  text-align: left;
}

.pending-receives h5 {
  text-align: center;
  margin-bottom: 8px;
  font-size: 14px;
}

.pending-item {
  padding: 8px;
  margin: 2px 0;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.05);
}

.pending-amount {
  font-size: 14px;
  font-weight: bold;
  color: #4caf50;
}

.pending-time {
  font-size: 10px;
  opacity: 0.7;
}

.instructions {
  margin: 20px 0;
  text-align: left;
  font-size: 12px;
}

.instructions h5 {
  text-align: center;
  margin-bottom: 8px;
  font-size: 14px;
}

.instructions ol {
  margin: 0;
  padding-left: 16px;
}

.instructions li {
  margin: 4px 0;
}

/* Wear OS specific adjustments */
@media screen and (max-width: 400px) {
  .qrcode-canvas {
    max-width: 160px;
    max-height: 160px;
  }

  .amount-btn {
    min-width: 50px;
    min-height: 36px;
    font-size: 10px;
  }

  .nfc-btn {
    min-height: 44px;
    font-size: 14px;
  }
}
</style>
