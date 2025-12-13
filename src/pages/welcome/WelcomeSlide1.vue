<!-- src/components/WelcomeSlide1.vue -->
<template>
  <div class="q-pa-md flex flex-center">
    <div class="text-center">
      <h2 class="q-mt-md">Welcome to Bitpoints</h2>
      <div class="text-left">
        <p class="q-mt-sm">Your personal Bitcoin-backed rewards wallet.</p>

        <q-expansion-item
          v-model="termsOpen"
          class="q-mt-lg terms-card"
          icon="policy"
          label="Terms and Conditions (tap to view)"
          expand-icon="keyboard_arrow_down"
          dense-toggle
        >
          <div class="q-pa-md text-left">
            <p class="q-mb-sm">
              By using Bitpoints, you agree to our terms of service. Please
              review the full terms before continuing.
            </p>
            <p class="q-mb-sm text-caption">
              • Use this app at your own risk<br />
              • Keep your wallet backup secure<br />
              • Bitcoin transactions are irreversible
            </p>
          </div>
        </q-expansion-item>

        <div class="q-mt-lg">
          <q-checkbox
            v-model="welcomeStore.termsAccepted"
            label="I have read and agree to the terms and conditions"
            class="q-mb-md"
            dense
          />
          <q-checkbox
            v-model="welcomeStore.seedPhraseValidated"
            label="I understand how to backup my wallet securely"
            class="q-mb-md"
            dense
          />
        </div>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { useWelcomeStore } from "src/stores/welcome";
import { ref } from "vue";

export default {
  name: "WelcomeSlide1",
  setup() {
    const welcomeStore = useWelcomeStore();
    const termsOpen = ref(false);

    return {
      welcomeStore,
      termsOpen,
    };
  },
};
</script>

<style scoped>
h2 {
  font-weight: bold;
}
p {
  font-size: large;
}

/* Scroll indicator for landscape mode */
.scroll-indicator {
  position: fixed;
  bottom: 20px;
  left: 50%;
  transform: translateX(-50%);
  background: rgba(0, 0, 0, 0.8);
  color: white;
  border-radius: 12px;
  cursor: pointer;
  animation: bounce 2s infinite;
  z-index: 1000;
  min-width: 200px;
  text-align: center;
}

.scroll-indicator:hover {
  background: rgba(0, 0, 0, 0.9);
}

.terms-card .q-item {
  background: rgba(0, 0, 0, 0.05);
  border-radius: 8px;
}

.q-checkbox__label {
  white-space: normal;
}

@keyframes bounce {
  0%,
  20%,
  50%,
  80%,
  100% {
    transform: translateX(-50%) translateY(0);
  }
  40% {
    transform: translateX(-50%) translateY(-10px);
  }
  60% {
    transform: translateX(-50%) translateY(-5px);
  }
}
</style>
