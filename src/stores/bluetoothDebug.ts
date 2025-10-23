/**
 * Bluetooth Debug Store
 *
 * Manages debug events and provides persistence across app restarts
 * Integrates with bluetoothLogger for centralized event management
 */

import { defineStore } from "pinia";
import { useLocalStorage } from "@vueuse/core";
import { btLog, BluetoothDebugEvent } from "src/utils/bluetoothLogger";

export const useBluetoothDebugStore = defineStore("bluetoothDebug", {
  state: () => ({
    // Debug settings
    enabled: useLocalStorage<boolean>("bluetooth-debug-enabled", true),
    logLevel: useLocalStorage<"debug" | "info" | "warn" | "error">(
      "bluetooth-debug-level",
      "info"
    ),
    maxStoredEvents: useLocalStorage<number>(
      "bluetooth-debug-max-events",
      1000
    ),

    // Real-time stats
    totalEvents: 0,
    eventsByType: {
      send: 0,
      receive: 0,
      claim: 0,
      error: 0,
      mint_check: 0,
      peer: 0,
      system: 0,
    } as Record<BluetoothDebugEvent["type"], number>,

    // Current session stats
    sessionStartTime: Date.now(),
    lastEventTime: null as number | null,

    // Filtering state
    currentFilter: "all" as BluetoothDebugEvent["type"] | "all",
    searchQuery: "",

    // Auto-scroll state
    autoScroll: true,

    // Export state
    isExporting: false,
  }),

  getters: {
    /**
     * Get filtered events based on current filter and search
     */
    filteredEvents: (state) => {
      let events = btLog.getEvents();

      // Apply type filter
      if (state.currentFilter !== "all") {
        events = events.filter((event) => event.type === state.currentFilter);
      }

      // Apply search filter
      if (state.searchQuery) {
        const query = state.searchQuery.toLowerCase();
        events = events.filter(
          (event) =>
            event.message.toLowerCase().includes(query) ||
            (event.data &&
              JSON.stringify(event.data).toLowerCase().includes(query))
        );
      }

      return events;
    },

    /**
     * Get recent events (last 50)
     */
    recentEvents: () => {
      return btLog.getRecentEvents(50);
    },

    /**
     * Get error events only
     */
    errorEvents: () => {
      return btLog.getEventsByLevel("error");
    },

    /**
     * Get events from last N minutes
     */
    eventsFromLastMinutes: () => (minutes: number) => {
      const cutoff = Date.now() - minutes * 60 * 1000;
      return btLog.getEvents().filter((event) => event.timestamp >= cutoff);
    },

    /**
     * Get session duration in minutes
     */
    sessionDurationMinutes: (state) => {
      return Math.round((Date.now() - state.sessionStartTime) / 60000);
    },

    /**
     * Get events per minute rate
     */
    eventsPerMinute: (state) => {
      const duration = state.sessionDurationMinutes;
      return duration > 0
        ? Math.round((state.totalEvents / duration) * 10) / 10
        : 0;
    },
  },

  actions: {
    /**
     * Initialize debug store and set up event listener
     */
    initialize() {
      // Set up event listener to track stats
      btLog.onEvent((event) => {
        this.totalEvents++;
        this.eventsByType[event.type]++;
        this.lastEventTime = event.timestamp;
      });

      // Load initial stats from existing events
      this.refreshStats();
    },

    /**
     * Refresh statistics from current events
     */
    refreshStats() {
      const events = btLog.getEvents();
      this.totalEvents = events.length;
      this.lastEventTime =
        events.length > 0 ? events[events.length - 1].timestamp : null;

      // Reset counters
      Object.keys(this.eventsByType).forEach((type) => {
        this.eventsByType[type as BluetoothDebugEvent["type"]] = 0;
      });

      // Count by type
      events.forEach((event) => {
        this.eventsByType[event.type]++;
      });
    },

    /**
     * Set filter type
     */
    setFilter(type: BluetoothDebugEvent["type"] | "all") {
      this.currentFilter = type;
    },

    /**
     * Set search query
     */
    setSearchQuery(query: string) {
      this.searchQuery = query;
    },

    /**
     * Clear search and filters
     */
    clearFilters() {
      this.currentFilter = "all";
      this.searchQuery = "";
    },

    /**
     * Toggle auto-scroll
     */
    toggleAutoScroll() {
      this.autoScroll = !this.autoScroll;
    },

    /**
     * Clear all debug events
     */
    clearEvents() {
      btLog.clear();
      this.refreshStats();
    },

    /**
     * Export events as JSON
     */
    async exportAsJSON(): Promise<string> {
      this.isExporting = true;
      try {
        const json = btLog.exportAsJSON();
        return json;
      } finally {
        this.isExporting = false;
      }
    },

    /**
     * Export events as text
     */
    async exportAsText(): Promise<string> {
      this.isExporting = true;
      try {
        const text = btLog.exportAsText();
        return text;
      } finally {
        this.isExporting = false;
      }
    },

    /**
     * Download events as file
     */
    async downloadEvents(format: "json" | "txt" = "txt") {
      try {
        const content =
          format === "json"
            ? await this.exportAsJSON()
            : await this.exportAsText();

        const blob = new Blob([content], {
          type: format === "json" ? "application/json" : "text/plain",
        });

        const url = URL.createObjectURL(blob);
        const link = document.createElement("a");
        link.href = url;
        link.download = `bluetooth-debug-${new Date()
          .toISOString()
          .slice(0, 19)
          .replace(/:/g, "-")}.${format}`;
        document.body.appendChild(link);
        link.click();
        document.body.removeChild(link);
        URL.revokeObjectURL(url);
      } catch (error) {
        console.error("Failed to download debug events:", error);
        throw error;
      }
    },

    /**
     * Get events for a specific time range
     */
    getEventsInRange(
      startTime: number,
      endTime: number
    ): BluetoothDebugEvent[] {
      return btLog
        .getEvents()
        .filter(
          (event) => event.timestamp >= startTime && event.timestamp <= endTime
        );
    },

    /**
     * Get events by peer ID
     */
    getEventsByPeer(peerId: string): BluetoothDebugEvent[] {
      return btLog
        .getEvents()
        .filter(
          (event) =>
            event.data &&
            (event.data.peerID === peerId ||
              event.data.senderPeerID === peerId ||
              event.data.recipientPeerID === peerId)
        );
    },

    /**
     * Get events by message ID
     */
    getEventsByMessageId(messageId: string): BluetoothDebugEvent[] {
      return btLog
        .getEvents()
        .filter((event) => event.data && event.data.messageId === messageId);
    },

    /**
     * Reset session stats
     */
    resetSession() {
      this.sessionStartTime = Date.now();
      this.totalEvents = 0;
      this.lastEventTime = null;
      Object.keys(this.eventsByType).forEach((type) => {
        this.eventsByType[type as BluetoothDebugEvent["type"]] = 0;
      });
    },
  },
});
