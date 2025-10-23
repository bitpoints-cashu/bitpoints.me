<template>
  <div class="bluetooth-debug-panel">
    <!-- Header -->
    <div class="debug-header">
      <div class="header-left">
        <h6 class="text-h6">🔵 Bluetooth Debug</h6>
        <div class="stats-row">
          <q-chip size="sm" color="primary" outline>
            {{ debugStore.totalEvents }} events
          </q-chip>
          <q-chip size="sm" color="positive" outline>
            {{ debugStore.sessionDurationMinutes }}m
          </q-chip>
          <q-chip size="sm" color="info" outline>
            {{ debugStore.eventsPerMinute }}/min
          </q-chip>
        </div>
      </div>
      <div class="header-right">
        <q-btn
          flat
          round
          icon="refresh"
          @click="refreshStats"
          :loading="isRefreshing"
        >
          <q-tooltip>Refresh Stats</q-tooltip>
        </q-btn>
        <q-btn
          flat
          round
          icon="download"
          @click="downloadLogs"
          :loading="debugStore.isExporting"
        >
          <q-tooltip>Download Logs</q-tooltip>
        </q-btn>
        <q-btn flat round icon="clear_all" @click="clearLogs" color="negative">
          <q-tooltip>Clear Logs</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Controls -->
    <div class="debug-controls">
      <div class="controls-left">
        <q-select
          v-model="debugStore.currentFilter"
          :options="filterOptions"
          label="Filter"
          dense
          outlined
          style="min-width: 120px"
        />
        <q-input
          v-model="debugStore.searchQuery"
          label="Search"
          dense
          outlined
          clearable
          style="min-width: 200px"
        >
          <template v-slot:prepend>
            <q-icon name="search" />
          </template>
        </q-input>
      </div>
      <div class="controls-right">
        <q-toggle
          v-model="debugStore.autoScroll"
          label="Auto-scroll"
          color="primary"
        />
        <q-btn flat dense icon="pause" @click="pauseLogs" v-if="!isPaused">
          <q-tooltip>Pause</q-tooltip>
        </q-btn>
        <q-btn flat dense icon="play_arrow" @click="resumeLogs" v-else>
          <q-tooltip>Resume</q-tooltip>
        </q-btn>
      </div>
    </div>

    <!-- Event Type Stats -->
    <div class="event-stats">
      <q-chip
        v-for="(count, type) in debugStore.eventsByType"
        :key="type"
        :color="getTypeColor(type)"
        :text-color="getTypeTextColor(type)"
        size="sm"
        clickable
        @click="setFilter(type)"
      >
        {{ type }}: {{ count }}
      </q-chip>
    </div>

    <!-- Log Display -->
    <div class="log-container" ref="logContainer">
      <div
        v-for="event in filteredEvents"
        :key="event.timestamp"
        :class="['log-entry', `log-${event.type}`, `log-${event.level}`]"
      >
        <div class="log-timestamp">
          {{ formatTime(event.timestamp) }}
        </div>
        <div class="log-type">
          {{ getTypeEmoji(event.type) }} {{ event.type.toUpperCase() }}
        </div>
        <div class="log-message">
          {{ event.message }}
        </div>
        <div v-if="event.data" class="log-data">
          <pre>{{ JSON.stringify(event.data, null, 2) }}</pre>
        </div>
      </div>
      <div v-if="filteredEvents.length === 0" class="no-events">
        No events found
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
import { ref, computed, onMounted, onUnmounted, nextTick, watch } from "vue";
import { useBluetoothDebugStore } from "src/stores/bluetoothDebug";
import { BluetoothDebugEvent } from "src/utils/bluetoothLogger";

const debugStore = useBluetoothDebugStore();
const logContainer = ref<HTMLElement>();
const isRefreshing = ref(false);
const isPaused = ref(false);

const filterOptions = [
  { label: "All", value: "all" },
  { label: "Send", value: "send" },
  { label: "Receive", value: "receive" },
  { label: "Claim", value: "claim" },
  { label: "Mint Check", value: "mint_check" },
  { label: "Peer", value: "peer" },
  { label: "Error", value: "error" },
  { label: "System", value: "system" },
];

const filteredEvents = computed(() => {
  return debugStore.filteredEvents;
});

// Auto-scroll to bottom when new events arrive
watch(filteredEvents, () => {
  if (debugStore.autoScroll && !isPaused.value) {
    nextTick(() => {
      scrollToBottom();
    });
  }
});

onMounted(() => {
  debugStore.initialize();
  refreshStats();
});

function refreshStats() {
  isRefreshing.value = true;
  debugStore.refreshStats();
  setTimeout(() => {
    isRefreshing.value = false;
  }, 500);
}

function setFilter(type: string) {
  debugStore.setFilter(type as BluetoothDebugEvent["type"] | "all");
}

function clearLogs() {
  debugStore.clearEvents();
}

async function downloadLogs() {
  try {
    await debugStore.downloadEvents("txt");
  } catch (error) {
    console.error("Failed to download logs:", error);
  }
}

function pauseLogs() {
  isPaused.value = true;
}

function resumeLogs() {
  isPaused.value = false;
  if (debugStore.autoScroll) {
    scrollToBottom();
  }
}

function scrollToBottom() {
  if (logContainer.value) {
    logContainer.value.scrollTop = logContainer.value.scrollHeight;
  }
}

function formatTime(timestamp: number): string {
  return new Date(timestamp).toLocaleTimeString("en-US", {
    hour12: false,
    hour: "2-digit",
    minute: "2-digit",
    second: "2-digit",
    fractionalSecondDigits: 3,
  });
}

function getTypeEmoji(type: string): string {
  const emojis = {
    send: "📤",
    receive: "📥",
    claim: "💰",
    error: "❌",
    mint_check: "🏦",
    peer: "👥",
    system: "⚙️",
  };
  return emojis[type as keyof typeof emojis] || "📝";
}

function getTypeColor(type: string): string {
  const colors = {
    send: "blue",
    receive: "green",
    claim: "orange",
    error: "red",
    mint_check: "purple",
    peer: "teal",
    system: "grey",
  };
  return colors[type as keyof typeof colors] || "grey";
}

function getTypeTextColor(type: string): string {
  return "white";
}
</script>

<style scoped>
.bluetooth-debug-panel {
  height: 100%;
  display: flex;
  flex-direction: column;
  background: #f5f5f5;
}

.debug-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 16px;
  background: white;
  border-bottom: 1px solid #e0e0e0;
}

.header-left h6 {
  margin: 0 0 8px 0;
}

.stats-row {
  display: flex;
  gap: 8px;
}

.header-right {
  display: flex;
  gap: 4px;
}

.debug-controls {
  display: flex;
  justify-content: space-between;
  align-items: center;
  padding: 12px 16px;
  background: white;
  border-bottom: 1px solid #e0e0e0;
}

.controls-left {
  display: flex;
  gap: 12px;
  align-items: center;
}

.controls-right {
  display: flex;
  gap: 8px;
  align-items: center;
}

.event-stats {
  padding: 8px 16px;
  background: white;
  border-bottom: 1px solid #e0e0e0;
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.log-container {
  flex: 1;
  overflow-y: auto;
  padding: 8px;
  background: #fafafa;
}

.log-entry {
  display: flex;
  align-items: flex-start;
  padding: 8px 12px;
  margin-bottom: 4px;
  border-radius: 4px;
  background: white;
  border-left: 4px solid #e0e0e0;
  font-family: "Courier New", monospace;
  font-size: 12px;
}

.log-entry.log-send {
  border-left-color: #2196f3;
}

.log-entry.log-receive {
  border-left-color: #4caf50;
}

.log-entry.log-claim {
  border-left-color: #ff9800;
}

.log-entry.log-error {
  border-left-color: #f44336;
  background: #ffebee;
}

.log-entry.log-mint_check {
  border-left-color: #9c27b0;
}

.log-entry.log-peer {
  border-left-color: #009688;
}

.log-entry.log-system {
  border-left-color: #607d8b;
}

.log-timestamp {
  color: #666;
  margin-right: 12px;
  min-width: 80px;
  flex-shrink: 0;
}

.log-type {
  color: #333;
  margin-right: 12px;
  min-width: 80px;
  flex-shrink: 0;
  font-weight: bold;
}

.log-message {
  flex: 1;
  color: #333;
}

.log-data {
  margin-top: 4px;
  color: #666;
  font-size: 11px;
  background: #f5f5f5;
  padding: 4px;
  border-radius: 2px;
  max-height: 100px;
  overflow-y: auto;
}

.log-data pre {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-all;
}

.no-events {
  text-align: center;
  color: #666;
  padding: 40px;
  font-style: italic;
}

/* Scrollbar styling */
.log-container::-webkit-scrollbar {
  width: 6px;
}

.log-container::-webkit-scrollbar-track {
  background: #f1f1f1;
}

.log-container::-webkit-scrollbar-thumb {
  background: #c1c1c1;
  border-radius: 3px;
}

.log-container::-webkit-scrollbar-thumb:hover {
  background: #a8a8a8;
}
</style>
