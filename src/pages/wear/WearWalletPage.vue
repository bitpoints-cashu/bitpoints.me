<template>
  <q-page class="wear-wallet-page">
    <!-- Header -->
    <div class="bitpoints-header">
      <img src="/icons/icon-48.webp" alt="Bitpoints" class="bitpoints-logo" />
      <h2>Bitpoints Wallet</h2>
    </div>

    <!-- Balance Display -->
    <div class="balance-display">
      <div class="balance-amount">{{ formatBalance(totalBalance) }}</div>
      <div class="balance-unit">sats</div>
    </div>

    <!-- Status Indicator -->
    <div class="status-section">
      <div class="status-item">
        <span class="status-indicator" :class="bluetoothStatusClass"></span>
        <span>{{ bluetoothStatusText }}</span>
      </div>
      <div class="status-item">
        <span class="status-indicator" :class="nostrStatusClass"></span>
        <span>{{ nostrStatusText }}</span>
      </div>
    </div>

    <!-- Quick Actions -->
    <div class="quick-actions">
      <q-btn
        class="quick-action-btn"
        color="primary"
        @click="navigateToSend"
        :disable="!canSend"
      >
        <q-icon name="send" />
        <span>Send</span>
      </q-btn>

      <q-btn
        class="quick-action-btn"
        color="secondary"
        @click="navigateToReceive"
      >
        <q-icon name="qr_code" />
        <span>Receive</span>
      </q-btn>

      <q-btn class="quick-action-btn" color="accent" @click="navigateToHistory">
        <q-icon name="history" />
        <span>History</span>
      </q-btn>
    </div>

    <!-- Recent Transactions Preview -->
    <div class="recent-transactions" v-if="recentTransactions.length > 0">
      <h4>Recent</h4>
      <div
        v-for="tx in recentTransactions.slice(0, 3)"
        :key="tx.id"
        class="transaction-item"
      >
        <div class="transaction-amount" :class="tx.type">
          {{ tx.type === "send" ? "-" : "+" }}{{ formatAmount(tx.amount) }}
        </div>
        <div class="transaction-time">{{ formatTime(tx.timestamp) }}</div>
      </div>
    </div>

    <!-- Ambient Mode Indicator -->
    <div v-if="isAmbientMode" class="ambient-indicator">
      <q-icon name="visibility" />
      <span>Ambient</span>
    </div>
  </q-page>
</template>

<script setup>
import { ref, computed, onMounted, onUnmounted } from "vue";
import { useRouter } from "vue-router";
import { useWalletStore } from "src/stores/wallet";
import { useBluetoothStore } from "src/stores/bluetooth";
import { useNostrStore } from "src/stores/nostr";
import { date } from "quasar";

const router = useRouter();
const walletStore = useWalletStore();
const bluetoothStore = useBluetoothStore();
const nostrStore = useNostrStore();

// Reactive data
const isAmbientMode = ref(false);
const recentTransactions = ref([]);

// Computed properties
const totalBalance = computed(() => {
  return walletStore.totalBalance || 0;
});

const canSend = computed(() => {
  return totalBalance.value > 0 && bluetoothStore.isConnected;
});

const bluetoothStatusClass = computed(() => {
  if (bluetoothStore.isScanning) return "status-scanning";
  if (bluetoothStore.isConnected) return "status-connected";
  return "status-disconnected";
});

const bluetoothStatusText = computed(() => {
  if (bluetoothStore.isScanning) return "Scanning...";
  if (bluetoothStore.isConnected) return "Bluetooth Active";
  return "Bluetooth Off";
});

const nostrStatusClass = computed(() => {
  return nostrStore.isConnected ? "status-connected" : "status-disconnected";
});

const nostrStatusText = computed(() => {
  return nostrStore.isConnected ? "Nostr Connected" : "Nostr Offline";
});

// Methods
const formatBalance = (amount) => {
  return new Intl.NumberFormat().format(amount);
};

const formatAmount = (amount) => {
  return new Intl.NumberFormat().format(amount);
};

const formatTime = (timestamp) => {
  return date.formatDate(timestamp, "HH:mm");
};

const navigateToSend = () => {
  router.push("/wear/send");
};

const navigateToReceive = () => {
  router.push("/wear/receive");
};

const navigateToHistory = () => {
  router.push("/wear/history");
};

// Lifecycle
onMounted(() => {
  // Load recent transactions
  loadRecentTransactions();

  // Set up ambient mode detection
  if (window.wearOS) {
    isAmbientMode.value = window.wearOS.ambientMode;
  }
});

onUnmounted(() => {
  // Cleanup if needed
});

const loadRecentTransactions = () => {
  // Load last 3 transactions from wallet store
  recentTransactions.value = walletStore.transactions.slice(0, 3);
};
</script>

<style scoped>
.wear-wallet-page {
  padding: 8px;
  text-align: center;
}

.balance-display {
  background: rgba(255, 255, 255, 0.1);
  border-radius: 12px;
  padding: 16px;
  margin: 16px 0;
}

.balance-amount {
  font-size: 24px;
  font-weight: bold;
  line-height: 1.2;
}

.balance-unit {
  font-size: 14px;
  opacity: 0.8;
  margin-top: 4px;
}

.status-section {
  margin: 16px 0;
}

.status-item {
  display: flex;
  align-items: center;
  justify-content: center;
  margin: 4px 0;
  font-size: 12px;
}

.quick-actions {
  margin: 20px 0;
}

.quick-action-btn {
  width: 100%;
  margin: 4px 0;
  min-height: 48px;
}

.recent-transactions {
  margin-top: 20px;
  text-align: left;
}

.recent-transactions h4 {
  text-align: center;
  margin-bottom: 8px;
  font-size: 14px;
}

.transaction-item {
  padding: 8px;
  margin: 2px 0;
  border-radius: 4px;
  background: rgba(255, 255, 255, 0.05);
}

.transaction-amount {
  font-size: 14px;
  font-weight: bold;
}

.transaction-amount.send {
  color: #f44336;
}

.transaction-amount.receive {
  color: #4caf50;
}

.transaction-time {
  font-size: 10px;
  opacity: 0.7;
}

.ambient-indicator {
  position: fixed;
  top: 8px;
  right: 8px;
  font-size: 10px;
  opacity: 0.6;
  display: flex;
  align-items: center;
  gap: 2px;
}

/* Wear OS specific adjustments */
@media screen and (max-width: 400px) {
  .balance-amount {
    font-size: 20px;
  }

  .quick-action-btn {
    min-height: 44px;
    font-size: 14px;
  }
}
</style>

