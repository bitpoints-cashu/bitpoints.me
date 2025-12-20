// PostMessage boot file for Bitpoints.me wallet
// Enables communication with admin dashboard iframes

export default ({ app }) => {
  // Only run in browser environment
  if (typeof window === "undefined") return;

  // Configure allowed origins for security
  const getAllowedOrigins = () => {
    const hostname = window.location.hostname;

    // Production: allow admin subdomain
    if (hostname.includes("bitpoints.me")) {
      return ["https://admin.bitpoints.me"];
    }

    // Local development: allow localhost admin
    return [
      "http://localhost:3000",
      "http://localhost:5173",
      "http://localhost:8080",
      "https://bitpoints.me",
    ];
  };

  const allowedOrigins = getAllowedOrigins();

  // PostMessage event handler
  const handlePostMessage = (event) => {
    // Validate origin
    if (!allowedOrigins.includes(event.origin)) {
      console.warn(
        "PostMessage: Received message from unauthorized origin:",
        event.origin
      );
      return;
    }

    try {
      const message = event.data;

      if (!message || typeof message !== "object" || !message.type) {
        return;
      }

      console.log("PostMessage: Received message:", message);

      // Handle different message types
      switch (message.type) {
        case "admin_ready":
          // Admin dashboard is ready, send wallet ready signal
          sendMessage({
            type: "wallet_ready",
            version: process.env.PACKAGE_VERSION || "0.1.9",
          });
          break;

        case "request_balance":
          // Send current balance
          sendBalanceUpdate();
          break;

        case "request_pay":
          // Handle pay request - could open send dialog
          console.log("Pay request received:", message.data);
          // TODO: Implement pay flow integration
          break;

        case "request_receive":
          // Handle receive request - could open receive dialog
          console.log("Receive request received:", message.data);
          // TODO: Implement receive flow integration
          break;

        default:
          console.log("Unknown postMessage type:", message.type);
      }
    } catch (error) {
      console.error("PostMessage: Error handling message:", error);
    }
  };

  // Send message to parent window (admin dashboard)
  const sendMessage = (message) => {
    if (window.parent && window.parent !== window) {
      const targetOrigin = allowedOrigins[0]; // Use first allowed origin
      window.parent.postMessage(message, targetOrigin);
      console.log("PostMessage: Sent message:", message);
    }
  };

  // Send balance update
  const sendBalanceUpdate = () => {
    // Get balance from wallet store if available
    try {
      // This assumes we have access to the wallet store
      // In a real implementation, you'd inject the store or use an event bus
      const balance = 0; // TODO: Get actual balance from store
      sendMessage({
        type: "wallet_balance_update",
        balance: balance,
      });
    } catch (error) {
      console.error("PostMessage: Error sending balance update:", error);
      sendMessage({
        type: "error",
        error: "Failed to get balance",
      });
    }
  };

  // Set up event listener
  window.addEventListener("message", handlePostMessage);

  // Send initial ready message when wallet loads
  // Delay slightly to ensure parent is ready
  setTimeout(() => {
    sendMessage({
      type: "wallet_ready",
      version: process.env.PACKAGE_VERSION || "0.1.9",
    });
  }, 1000);

  // Store reference for cleanup if needed
  app.config.globalProperties.$postMessage = {
    sendMessage,
    sendBalanceUpdate,
  };
};
