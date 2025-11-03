<template>
  <q-btn
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
  mounted() {},
  watch: {},
  computed: {
    ...mapState(useSettingsStore, ["walletDisplayUnit"]),
    activeUnitLabelAdopted: function () {
      return this.walletDisplayUnit === "sat" ? "Sats" : "Points";
    },
  },
  methods: {
    toggleUnit: function () {
      const settingsStore = useSettingsStore();
      settingsStore.walletDisplayUnit = this.walletDisplayUnit === "sat" ? "points" : "sat";
    },
  },
});
</script>
