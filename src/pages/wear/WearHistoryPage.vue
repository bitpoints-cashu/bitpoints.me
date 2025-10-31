<template>
  <q-page class="wear-history-page">
    <!-- Header -->
    <div class="bitpoints-header">
      <h2>Transaction History</h2>
      <q-btn flat round icon="arrow_back" @click="goBack" class="back-btn" />
    </div>

    <!-- Summary -->
    <div class="summary-section">
      <div class="summary-item">
        <div class="summary-label">Total Sent</div>
        <div class="summary-value sent">{{ formatAmount(totalSent) }}</div>
      </div>
      <div class="summary-item">
        <div class="summary-label">Total Received</div>
        <div class="summary-value received">
          {{ formatAmount(totalReceived) }}
        </div>
      </div>
    </div>

    <!-- Filter Options -->
    <div class="filter-section">
      <q-btn-toggle
        v-model="filterType"
        :options="filterOptions"
        color="primary"
        class="filter-toggle"
      />
    </div>

    <!-- Transaction List -->
    <div class="transactions-section">
      <div v-if="isLoading" class="loading-state">
        <q-spinner size="24px" />
        <p>Loading transactions...</p>
      </div>

      <div v-else-if="filteredTransactions.length === 0" class="empty-state">
        <q-icon name="history" size="32px" />
        <p>No transactions found</p>
      </div>

      <div v-else class="transactions-list">
        <div
          v-for="tx in filteredTransactions"
          :key="tx.id"
          class="transaction-item"
          @click="showTransactionDetails(tx)"
        >
          <div class="transaction-icon">
            <q-icon
              :name="tx.type === 'send' ? 'send' : 'receive'"
              :color="tx.type === 'send' ? 'negative' : 'positive'"
            />
          </div>

          <div class="transaction-info">
            <div class="transaction-amount" :class="tx.type">
              {{ tx.type === "send" ? "-" : "+" }}{{ formatAmount(tx.amount) }}
            </div>
            <div class="transaction-details">
              <div class="transaction-method">
                {{ getTransactionMethod(tx) }}
              </div>
              <div class="transaction-time">{{ formatTime(tx.timestamp) }}</div>
            </div>
          </div>

          <div class="transaction-status">
            <q-icon
              :name="getStatusIcon(tx.status)"
              :color="getStatusColor(tx.status)"
              size="16px"
            />
          </div>
        </div>
      </div>
    </div>

    <!-- Load More -->
    <div v-if="hasMoreTransactions" class="load-more-section">
      <q-btn
        color="secondary"
        @click="loadMoreTransactions"
        :loading="isLoadingMore"
        class="load-more-btn"
      >
        Load More
      </q-btn>
    </div>

    <!-- Transaction Details Dialog -->
    <q-dialog v-model="showDetails" class="transaction-details-dialog">
      <q-card v-if="selectedTransaction" class="details-card">
        <q-card-section class="details-header">
          <div class="details-title">
            <q-icon
              :name="selectedTransaction.type === 'send' ? 'send' : 'receive'"
              :color="
                selectedTransaction.type === 'send' ? 'negative' : 'positive'
              "
            />
            <span>{{
              selectedTransaction.type === "send" ? "Sent" : "Received"
            }}</span>
          </div>
          <q-btn flat round icon="close" @click="showDetails = false" />
        </q-card-section>

        <q-card-section class="details-content">
          <div class="detail-row">
            <span class="detail-label">Amount</span>
            <span class="detail-value" :class="selectedTransaction.type">
              {{ selectedTransaction.type === "send" ? "-" : "+"
              }}{{ formatAmount(selectedTransaction.amount) }} sats
            </span>
          </div>

          <div class="detail-row">
            <span class="detail-label">Method</span>
            <span class="detail-value">{{
              getTransactionMethod(selectedTransaction)
            }}</span>
          </div>

          <div class="detail-row">
            <span class="detail-label">Time</span>
            <span class="detail-value">{{
              formatDateTime(selectedTransaction.timestamp)
            }}</span>
          </div>

          <div class="detail-row" v-if="selectedTransaction.peer">
            <span class="detail-label">Peer</span>
            <span class="detail-value">{{
              selectedTransaction.peer.name || "Unknown"
            }}</span>
          </div>

          <div class="detail-row" v-if="selectedTransaction.mint">
            <span class="detail-label">Mint</span>
            <span class="detail-value">{{
              selectedTransaction.mint.name
            }}</span>
          </div>

          <div class="detail-row">
            <span class="detail-label">Status</span>
            <span
              class="detail-value"
              :class="getStatusColor(selectedTransaction.status)"
            >
              {{ getStatusText(selectedTransaction.status) }}
            </span>
          </div>
        </q-card-section>

        <q-card-actions class="details-actions">
          <q-btn color="primary" @click="copyTransactionId" class="copy-btn">
            <q-icon name="content_copy" />
            Copy ID
          </q-btn>
        </q-card-actions>
      </q-card>
    </q-dialog>
  </q-page>
</template>

<script setup lang="js">
import { ref, computed, onMounted } from "vue";
import { useRouter } from "vue-router";
import { useWalletStore } from "src/stores/wallet";
import { Notify } from "quasar";

const router = useRouter();
const walletStore = useWalletStore();

// Reactive data
const filterType = ref("all");
const isLoading = ref(false);
const isLoadingMore = ref(false);
const showDetails = ref(false);
const selectedTransaction = ref(null);
const hasMoreTransactions = ref(false);

// Filter options
const filterOptions = ref([
  { label: "All", value: "all" },
  { label: "Sent", value: "send" },
  { label: "Received", value: "receive" },
]);

// Computed properties
const filteredTransactions = computed(() => {
  let transactions = walletStore.transactions || [];

  if (filterType.value !== "all") {
    transactions = transactions.filter((tx) => tx.type === filterType.value);
  }

  return transactions.slice(0, 20); // Limit for watch display
});

const totalSent = computed(() => {
  return (walletStore.transactions || [])
    .filter((tx) => tx.type === "send")
    .reduce((sum, tx) => sum + tx.amount, 0);
});

const totalReceived = computed(() => {
  return (walletStore.transactions || [])
    .filter((tx) => tx.type === "receive")
    .reduce((sum, tx) => sum + tx.amount, 0);
});

// Methods
const formatAmount = (amount) => {
  return new Intl.NumberFormat().format(amount);
};

const formatTime = (timestamp) => {
  const date = new Date(timestamp);
  const now = new Date();
  const diff = now - date;

  if (diff < 60000) return "Just now";
  if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
  if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;
  return date.toLocaleDateString();
};

const formatDateTime = (timestamp) => {
  return new Date(timestamp).toLocaleString();
};

const getTransactionMethod = (tx) => {
  if (tx.method === "bluetooth") return "Bluetooth";
  if (tx.method === "nostr") return "Nostr";
  if (tx.method === "lightning") return "Lightning";
  if (tx.method === "qr") return "QR Code";
  return "Unknown";
};

const getStatusIcon = (status) => {
  switch (status) {
    case "completed":
      return "check_circle";
    case "pending":
      return "schedule";
    case "failed":
      return "error";
    default:
      return "help";
  }
};

const getStatusColor = (status) => {
  switch (status) {
    case "completed":
      return "positive";
    case "pending":
      return "warning";
    case "failed":
      return "negative";
    default:
      return "grey";
  }
};

const getStatusText = (status) => {
  switch (status) {
    case "completed":
      return "Completed";
    case "pending":
      return "Pending";
    case "failed":
      return "Failed";
    default:
      return "Unknown";
  }
};

const goBack = () => {
  router.push("/wear/wallet");
};

const showTransactionDetails = (tx) => {
  selectedTransaction.value = tx;
  showDetails.value = true;
};

const loadMoreTransactions = async () => {
  isLoadingMore.value = true;

  try {
    // Load more transactions from store
    await walletStore.loadMoreTransactions();
  } catch (error) {
    console.error("Load more error:", error);
  } finally {
    isLoadingMore.value = false;
  }
};

const copyTransactionId = () => {
  if (selectedTransaction.value?.id) {
    navigator.clipboard.writeText(selectedTransaction.value.id);
    Notify.create({
      type: "positive",
      message: "Transaction ID copied",
      position: "top",
    });
  }
};

// Lifecycle
onMounted(() => {
  // Load transactions if not already loaded
  if (!walletStore.transactions?.length) {
    isLoading.value = true;
    walletStore.loadTransactions().finally(() => {
      isLoading.value = false;
    });
  }
});
</script>

<style scoped>
.wear-history-page {
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

.summary-section {
  display: flex;
  justify-content: space-around;
  margin: 16px 0;
  padding: 12px;
  background: rgba(255, 255, 255, 0.05);
  border-radius: 8px;
}

.summary-item {
  text-align: center;
}

.summary-label {
  font-size: 12px;
  opacity: 0.7;
  margin-bottom: 4px;
}

.summary-value {
  font-size: 16px;
  font-weight: bold;
}

.summary-value.sent {
  color: #f44336;
}

.summary-value.received {
  color: #4caf50;
}

.filter-section {
  margin: 16px 0;
  text-align: center;
}

.filter-toggle {
  width: 100%;
}

.transactions-section {
  margin: 16px 0;
}

.loading-state,
.empty-state {
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  padding: 40px 20px;
  color: #666;
}

.loading-state p,
.empty-state p {
  margin: 8px 0;
  font-size: 14px;
}

.transactions-list {
  max-height: 300px;
  overflow-y: auto;
}

.transaction-item {
  display: flex;
  align-items: center;
  padding: 12px;
  margin: 4px 0;
  border-radius: 8px;
  background: rgba(255, 255, 255, 0.05);
  border: 1px solid rgba(255, 255, 255, 0.1);
  cursor: pointer;
  transition: all 0.2s;
}

.transaction-item:hover {
  background: rgba(255, 255, 255, 0.1);
}

.transaction-icon {
  margin-right: 12px;
}

.transaction-info {
  flex: 1;
}

.transaction-amount {
  font-size: 16px;
  font-weight: bold;
  margin-bottom: 2px;
}

.transaction-amount.send {
  color: #f44336;
}

.transaction-amount.receive {
  color: #4caf50;
}

.transaction-details {
  display: flex;
  justify-content: space-between;
  font-size: 12px;
  opacity: 0.7;
}

.transaction-method {
  font-weight: 500;
}

.transaction-status {
  margin-left: 8px;
}

.load-more-section {
  margin: 20px 0;
  text-align: center;
}

.load-more-btn {
  width: 100%;
  min-height: 48px;
}

/* Transaction Details Dialog */
.transaction-details-dialog .q-dialog__inner {
  padding: 8px;
}

.details-card {
  width: 100%;
  max-width: 100%;
}

.details-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 8px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.1);
}

.details-title {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 18px;
  font-weight: bold;
}

.details-content {
  padding: 16px 0;
}

.detail-row {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 8px 0;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
}

.detail-label {
  font-size: 14px;
  opacity: 0.7;
}

.detail-value {
  font-size: 14px;
  font-weight: 500;
  text-align: right;
}

.detail-value.send {
  color: #f44336;
}

.detail-value.receive {
  color: #4caf50;
}

.details-actions {
  padding-top: 8px;
  border-top: 1px solid rgba(255, 255, 255, 0.1);
}

.copy-btn {
  width: 100%;
  min-height: 48px;
}

/* Wear OS specific adjustments */
@media screen and (max-width: 400px) {
  .summary-section {
    padding: 8px;
  }

  .summary-value {
    font-size: 14px;
  }

  .transaction-item {
    padding: 10px;
  }

  .transaction-amount {
    font-size: 14px;
  }

  .transaction-details {
    font-size: 10px;
  }

  .details-title {
    font-size: 16px;
  }

  .detail-row {
    padding: 6px 0;
  }

  .detail-label,
  .detail-value {
    font-size: 12px;
  }
}
</style>
