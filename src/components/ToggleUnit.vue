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
import { mapActions, mapState } from "pinia";
import { useMintsStore } from "stores/mints";
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
    ...mapState(useMintsStore, ["activeUnit", "activeUnitLabel"]),
    activeUnitLabelAdopted: function () {
      // Show Points when unit is sat
      if (this.activeUnit === "sat") {
        return "Points";
      } else {
        return this.activeUnitLabel;
      }
    },
  },
  methods: {
    ...mapActions(useMintsStore, ["toggleUnit"]),
  },
});
</script>
