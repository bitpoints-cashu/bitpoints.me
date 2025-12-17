/**
 * Safe Area Handler
 *
 * Simple JavaScript solution to handle safe area insets
 * This ensures proper layout on devices with notches/Dynamic Island
 */
(function () {
  "use strict";

  // Function to update safe area CSS
  function updateSafeAreaCSS() {
    // Get safe area insets using CSS env() function
    const css = `
            :root {
                --safe-area-inset-top: env(safe-area-inset-top, 0px);
                --safe-area-inset-bottom: env(safe-area-inset-bottom, 0px);
                --safe-area-inset-left: env(safe-area-inset-left, 0px);
                --safe-area-inset-right: env(safe-area-inset-right, 0px);
            }
            
            /* Ensure body respects safe areas */
            body {
                padding-top: env(safe-area-inset-top, 0px) !important;
                padding-bottom: env(safe-area-inset-bottom, 0px) !important;
                padding-left: env(safe-area-inset-left, 0px) !important;
                padding-right: env(safe-area-inset-right, 0px) !important;
            }
            
            /* Fix for Quasar components */
            .q-drawer, .q-header {
                margin-top: env(safe-area-inset-top, 0px) !important;
            }
            
            /* Ensure content doesn't overlap with status bar */
            .q-page {
                padding-top: env(safe-area-inset-top, 0px) !important;
            }
            
            /* Fix for toolbar/header being blocked by front camera */
            .q-toolbar, .q-header {
                padding-top: max(env(safe-area-inset-top, 0px), 80px) !important;
                min-height: calc(100px + env(safe-area-inset-top, 0px)) !important;
            }
            
            /* Fix for logo being blocked - move it down significantly */
            .q-toolbar__title, .q-header__title {
                margin-top: max(env(safe-area-inset-top, 0px), 20px) !important;
                padding-top: 20px !important;
            }
            
            /* Ensure buttons and interactive elements are accessible */
            .q-btn, .q-fab {
                margin-top: max(env(safe-area-inset-top, 0px), 20px) !important;
            }
            
            /* Fix for settings menu and other overlays */
            .q-menu, .q-dialog, .q-popup {
                margin-top: max(env(safe-area-inset-top, 0px), 80px) !important;
            }
            
            /* Ensure navigation elements are below camera */
            .q-tabs, .q-tab {
                margin-top: max(env(safe-area-inset-top, 0px), 20px) !important;
            }
            
            /* Fix for any content being blocked by camera */
            .q-page, .q-layout {
                padding-top: env(safe-area-inset-top, 0px) !important;
            }
            
            /* Ensure main content area is below camera */
            .q-page-container {
                margin-top: env(safe-area-inset-top, 0px) !important;
            }
            
            /* Fix for any fixed positioned elements */
            .q-fixed {
                top: env(safe-area-inset-top, 0px) !important;
            }
            
            /* Additional fixes for settings and navigation */
            .q-drawer, .q-side {
                margin-top: max(env(safe-area-inset-top, 0px), 80px) !important;
            }
            
            /* Fix for any modal or overlay content */
            .q-card, .q-list {
                margin-top: max(env(safe-area-inset-top, 0px), 20px) !important;
            }
            
            /* Ensure close buttons are accessible */
            .q-btn--close, .q-btn--dense {
                margin-top: max(env(safe-area-inset-top, 0px), 20px) !important;
            }
        `;

    // Remove existing safe area styles
    const existingStyle = document.getElementById("safe-area-styles");
    if (existingStyle) {
      existingStyle.remove();
    }

    // Add new safe area styles
    const style = document.createElement("style");
    style.id = "safe-area-styles";
    style.textContent = css;
    document.head.appendChild(style);

    console.log("Safe area CSS updated");
  }

  // Function to handle orientation changes
  function handleOrientationChange() {
    setTimeout(updateSafeAreaCSS, 100);
  }

  // Initialize when DOM is ready
  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", updateSafeAreaCSS);
  } else {
    updateSafeAreaCSS();
  }

  // Handle orientation changes
  window.addEventListener("orientationchange", handleOrientationChange);
  window.addEventListener("resize", handleOrientationChange);

  // Also update when Capacitor is ready
  document.addEventListener("deviceready", updateSafeAreaCSS);

  // Export for manual updates if needed
  window.updateSafeAreaCSS = updateSafeAreaCSS;
})();
