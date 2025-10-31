/**
 * Bluetooth Debug Logger
 *
 * Centralized logging utility for Bluetooth token transfers
 * Provides structured logging with timestamps and categorization
 */

export interface BluetoothDebugEvent {
  timestamp: number;
  type:
    | "send"
    | "receive"
    | "claim"
    | "error"
    | "mint_check"
    | "peer"
    | "system";
  message: string;
  data?: any;
  level: "info" | "warn" | "error" | "debug";
}

class BluetoothLogger {
  private events: BluetoothDebugEvent[] = [];
  private maxEvents = 1000;
  private listeners: ((event: BluetoothDebugEvent) => void)[] = [];

  /**
   * Add a new debug event
   */
  private addEvent(
    type: BluetoothDebugEvent["type"],
    message: string,
    data?: any,
    level: BluetoothDebugEvent["level"] = "info"
  ) {
    const event: BluetoothDebugEvent = {
      timestamp: Date.now(),
      type,
      message,
      data,
      level,
    };

    this.events.push(event);

    // Keep only last maxEvents
    if (this.events.length > this.maxEvents) {
      this.events = this.events.slice(-this.maxEvents);
    }

    // Notify listeners
    this.listeners.forEach((listener) => listener(event));
  }

  /**
   * Get emoji for event type
   */
  private getEmoji(type: BluetoothDebugEvent["type"]): string {
    const emojis = {
      send: "📤",
      receive: "📥",
      claim: "💰",
      error: "❌",
      mint_check: "🏦",
      peer: "👥",
      system: "⚙️",
    };
    return emojis[type] || "📝";
  }

  /**
   * Log send event
   */
  send(message: string, data?: any) {
    this.addEvent("send", message, data, "info");
  }

  /**
   * Log receive event
   */
  receive(message: string, data?: any) {
    this.addEvent("receive", message, data, "info");
  }

  /**
   * Log claim event
   */
  claim(message: string, data?: any) {
    this.addEvent("claim", message, data, "info");
  }

  /**
   * Log error event
   */
  error(message: string, data?: any) {
    this.addEvent("error", message, data, "error");
  }

  /**
   * Log mint check event
   */
  mint(message: string, data?: any) {
    this.addEvent("mint_check", message, data, "info");
  }

  /**
   * Log peer event
   */
  peer(message: string, data?: any) {
    this.addEvent("peer", message, data, "info");
  }

  /**
   * Log system event
   */
  system(message: string, data?: any) {
    this.addEvent("system", message, data, "info");
  }

  /**
   * Get all events
   */
  getEvents(): BluetoothDebugEvent[] {
    return [...this.events];
  }

  /**
   * Get events filtered by type
   */
  getEventsByType(type: BluetoothDebugEvent["type"]): BluetoothDebugEvent[] {
    return this.events.filter((event) => event.type === type);
  }

  /**
   * Get events filtered by level
   */
  getEventsByLevel(level: BluetoothDebugEvent["level"]): BluetoothDebugEvent[] {
    return this.events.filter((event) => event.level === level);
  }

  /**
   * Search events by message content
   */
  searchEvents(query: string): BluetoothDebugEvent[] {
    const lowerQuery = query.toLowerCase();
    return this.events.filter(
      (event) =>
        event.message.toLowerCase().includes(lowerQuery) ||
        (event.data &&
          JSON.stringify(event.data).toLowerCase().includes(lowerQuery))
    );
  }

  /**
   * Clear all events
   */
  clear() {
    this.events = [];
  }

  /**
   * Export events as JSON
   */
  exportAsJSON(): string {
    return JSON.stringify(
      {
        exportedAt: new Date().toISOString(),
        totalEvents: this.events.length,
        events: this.events,
      },
      null,
      2
    );
  }

  /**
   * Export events as text
   */
  exportAsText(): string {
    const lines = this.events.map((event) => {
      const timeStr = new Date(event.timestamp).toLocaleTimeString("en-US", {
        hour12: false,
        hour: "2-digit",
        minute: "2-digit",
        second: "2-digit",
        fractionalSecondDigits: 3,
      });
      const emoji = this.getEmoji(event.type);
      const dataStr = event.data
        ? ` | Data: ${JSON.stringify(event.data)}`
        : "";
      return `[${timeStr}] ${emoji} [${event.type.toUpperCase()}] ${
        event.message
      }${dataStr}`;
    });

    return lines.join("\n");
  }

  /**
   * Subscribe to new events
   */
  onEvent(callback: (event: BluetoothDebugEvent) => void) {
    this.listeners.push(callback);
    return () => {
      const index = this.listeners.indexOf(callback);
      if (index > -1) {
        this.listeners.splice(index, 1);
      }
    };
  }

  /**
   * Get recent events (last N events)
   */
  getRecentEvents(count: number = 50): BluetoothDebugEvent[] {
    return this.events.slice(-count);
  }
}

// Create singleton instance
export const btLog = new BluetoothLogger();

// Export the class for testing
export { BluetoothLogger };
