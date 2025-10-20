<template>
  <q-layout view="hHh lpR fFf" class="wear-layout">
    <q-page-container>
      <router-view />
    </q-page-container>
  </q-layout>
</template>

<script setup>
import { onMounted, onUnmounted } from "vue";

// Wear OS specific setup
onMounted(() => {
  // Add Wear OS class to body
  document.body.classList.add("wear-os");

  // Set up Wear OS specific handlers
  setupWearOSHandlers();
});

onUnmounted(() => {
  // Cleanup Wear OS handlers
  document.body.classList.remove("wear-os");
});

const setupWearOSHandlers = () => {
  // Handle ambient mode changes
  if (window.wearOS) {
    window.wearOS.onAmbientModeChange = (isAmbient) => {
      document.body.classList.toggle("ambient-mode", isAmbient);
    };
  }

  // Handle rotary input for scrolling
  setupRotaryInput();

  // Handle touch gestures
  setupTouchGestures();
};

const setupRotaryInput = () => {
  // Rotary input handling for Wear OS
  let rotaryDelta = 0;

  const handleRotary = (event) => {
    rotaryDelta += event.deltaY || 0;

    // Scroll based on rotary input
    const scrollContainer = document.querySelector(".q-scrollarea");
    if (scrollContainer) {
      scrollContainer.scrollTop += rotaryDelta * 2;
      rotaryDelta = 0;
    }
  };

  // Listen for rotary events (if available)
  if ("onrotary" in window) {
    window.addEventListener("rotary", handleRotary);
  }
};

const setupTouchGestures = () => {
  // Handle swipe gestures for navigation
  let startX = 0;
  let startY = 0;

  const handleTouchStart = (event) => {
    startX = event.touches[0].clientX;
    startY = event.touches[0].clientY;
  };

  const handleTouchEnd = (event) => {
    const endX = event.changedTouches[0].clientX;
    const endY = event.changedTouches[0].clientY;
    const deltaX = endX - startX;
    const deltaY = endY - startY;

    // Horizontal swipe for navigation
    if (Math.abs(deltaX) > Math.abs(deltaY) && Math.abs(deltaX) > 50) {
      if (deltaX > 0) {
        // Swipe right - go back
        if (window.history.length > 1) {
          window.history.back();
        }
      } else {
        // Swipe left - could implement forward navigation
      }
    }
  };

  document.addEventListener("touchstart", handleTouchStart, { passive: true });
  document.addEventListener("touchend", handleTouchEnd, { passive: true });
};
</script>

<style scoped>
.wear-layout {
  background: #000;
  color: #fff;
}

/* Wear OS specific styles */
:global(.wear-os) {
  font-size: 14px;
  line-height: 1.4;
}

:global(.wear-os .q-page) {
  padding: 4px;
  min-height: 100vh;
}

:global(.wear-os .q-btn) {
  min-height: 48px;
  font-size: 16px;
  margin: 4px 0;
}

:global(.wear-os .q-card) {
  margin: 4px 0;
  padding: 8px;
  border-radius: 8px;
}

:global(.wear-os .q-input) {
  font-size: 16px;
}

:global(.wear-os .q-field__control) {
  min-height: 48px;
}

/* Ambient mode styles */
:global(.ambient-mode) {
  background: #000 !important;
  color: #fff !important;
}

:global(.ambient-mode .q-btn),
:global(.ambient-mode .q-card),
:global(.ambient-mode .q-input) {
  opacity: 0.8;
}

:global(.ambient-mode .balance-display) {
  font-size: 20px;
  opacity: 0.9;
}

/* High contrast for outdoor visibility */
@media (prefers-contrast: high) {
  :global(.wear-os) {
    background: #000;
    color: #fff;
  }

  :global(.wear-os .q-btn) {
    border: 2px solid #fff;
  }

  :global(.wear-os .q-card) {
    border: 1px solid #fff;
  }
}

/* Reduced motion for battery saving */
@media (prefers-reduced-motion: reduce) {
  :global(.wear-os *) {
    animation-duration: 0.01ms !important;
    animation-iteration-count: 1 !important;
    transition-duration: 0.01ms !important;
  }
}
</style>

