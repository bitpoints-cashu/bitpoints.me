<template>
  <q-btn
    v-if="shouldShowToggle"
    rounded
    outline
    :color="color"
    @click="toggleUnit()"
    :label="activeUnitLabelAdopted"
  />
</template>
<script lang="ts">
import { defineComponent } from "vue";
import { getShortUrl } from "src/js/wallet-helpers";
import { mapActions, mapState, mapWritableState } from "pinia";
import { useMintsStore } from "stores/mints";
import { useSettingsStore } from "stores/settings";
export default defineComponent({
  name: "ToggleUnit",
  mixins: [windowMixin],
  props: {
    balanceView: {
      type: Boolean,
      required: false,
    },
    color: {
      type: String,
      default: "primary",
    },
  },
  data: function () {
    return {
      chosenMint: null,
    };
  },
  mounted() {
    // Ensure initial state is correct
    this.handleUnitAvailabilityChange();
  },
  watch: {
    showBitcoin: function (newValue) {
      this.handleUnitAvailabilityChange();
    },
    showPoints: function (newValue) {
      this.handleUnitAvailabilityChange();
    },
  },
  computed: {
    ...mapState(useSettingsStore, [
      "walletDisplayUnit",
      "showBitcoin",
      "showPoints",
    ]),
    activeUnitLabelAdopted: function () {
      return this.walletDisplayUnit === "sat" ? "Sats" : "Points";
    },
    shouldShowToggle: function () {
      // Only show toggle when both Bitcoin and Points are enabled
      return this.showBitcoin && this.showPoints;
    },
  },
  methods: {
    toggleUnit: function () {
      const settingsStore = useSettingsStore();
      settingsStore.walletDisplayUnit =
        this.walletDisplayUnit === "sat" ? "points" : "sat";
    },
    handleUnitAvailabilityChange: function () {
      const settingsStore = useSettingsStore();
      const currentUnit = this.walletDisplayUnit;

      // If current unit is disabled, switch to the other enabled unit
      if (currentUnit === "sat" && !this.showBitcoin && this.showPoints) {
        settingsStore.walletDisplayUnit = "points";
      } else if (
        currentUnit === "points" &&
        !this.showPoints &&
        this.showBitcoin
      ) {
        settingsStore.walletDisplayUnit = "sat";
      }

      // If both are enabled and we're not showing toggle, ensure we're on a valid unit
      if (this.showBitcoin && this.showPoints) {
        // Both enabled, no change needed for toggle case
        return;
      }

      // If only one is enabled, ensure we're showing that one
      if (this.showBitcoin && !this.showPoints && currentUnit !== "sat") {
        settingsStore.walletDisplayUnit = "sat";
      } else if (
        this.showPoints &&
        !this.showBitcoin &&
        currentUnit !== "points"
      ) {
        settingsStore.walletDisplayUnit = "points";
      }
    },
  },
});
</script>
