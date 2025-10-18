<template>
  <AddMintDialog
    :addMintData="addMintData"
    :showAddMintDialog="showAddMintDialog"
    @update:showAddMintDialog="showAddMintDialog = $event"
    :addMintBlocking="addMintBlocking"
    @add="addMintInternal"
  />

  <div style="max-width: 800px; margin: 0 auto">
    <!-- ////////////////////// SETTINGS ////////////////// -->
    <div class="q-py-md q-px-xs text-left" on-left>
      <q-list padding>
        <!-- <q-item-label header>Your mints</q-item-label> -->
        <div v-for="mint in mints" :key="mint.url" class="q-px-md">
          <q-item
            :active="mint.url == activeMintUrl"
            active-class="text-weight-bold text-primary"
            clickable
            @click="activateMintUrlInternal(mint.url)"
            class="mint-card q-mb-md cursor-pointer"
            :style="{
              'border-radius': '10px',
              border:
                mint.url == activeMintUrl
                  ? '1px solid var(--q-primary) !important'
                  : '1px solid rgba(128, 128, 128, 0.2) !important',
              padding: '0px',
              position: 'relative',
            }"
            :loading="mint.url == activatingMintUrl"
          >
            <!-- hourglass spinner if mint is being activated -->
            <transition
              appear
              enter-active-class="animated fadeIn"
              leave-active-class="animated fadeOut"
              name="fade"
            >
              <q-spinner-hourglass
                v-if="mint.url == activatingMintUrl"
                color="white"
                size="1.3rem"
                class="mint-loading-spinner"
              />
            </transition>
            <transition
              appear
              enter-active-class="animated fadeIn"
              leave-active-class="animated fadeOut"
              name="fade"
            >
              <div
                v-if="mint.url != activatingMintUrl && mint.errored"
                class="error-badge"
              >
                <q-badge
                  color="red"
                  outline
                  class="q-mr-xs q-mt-sm text-weight-bold"
                >
                  Error
                  <q-icon name="error" class="q-ml-xs" size="xs" />
                </q-badge>
              </div>
            </transition>
            <div class="full-width" style="position: relative">
              <div class="row items-center q-pa-md">
                <div class="col">
                  <div class="row items-center">
                    <q-avatar
                      v-if="getMintIconUrl(mint)"
                      size="34px"
                      class="q-mr-sm"
                    >
                      <q-img
                        spinner-color="white"
                        spinner-size="xs"
                        :src="getMintIconUrl(mint)"
                        alt="Mint Icon"
                        style="height: 34px; max-width: 34px; font-size: 12px"
                      />
                    </q-avatar>

                    <div class="mint-info-container">
                      <div
                        v-if="mint.nickname || mint.info?.name"
                        class="mint-name"
                      >
                        {{ mint.nickname || mint.info?.name }}
                      </div>
                      <div class="text-grey-6 mint-url">
                        {{ mint.url }}
                      </div>
                    </div>
                  </div>
                </div>
              </div>

              <div class="row justify-between q-pb-md q-pl-lg q-pr-md">
                <div class="col">
                  <!-- Currency units with regular text styling -->
                  <div class="row q-gutter-x-sm">
                    <div
                      v-for="unit in mintClass(mint).units"
                      :key="unit"
                      class="currency-unit-badge"
                    >
                      <span class="currency-unit-text">
                        {{
                          formatCurrency(
                            mintClass(mint).unitBalance(unit),
                            unit
                          )
                        }}
                      </span>
                    </div>
                  </div>
                </div>

                <div class="col-auto">
                  <q-icon
                    name="more_vert"
                    @click.stop="showMintInfo(mint)"
                    color="white"
                    class="cursor-pointer q-mr-sm"
                    size="1.3rem"
                  />
                </div>
              </div>
            </div>
          </q-item>
        </div>
      </q-list>
    </div>
    <!-- Advanced Features Section -->
    <div class="section-divider q-mb-md">
      <div class="divider-line"></div>
      <div class="divider-text">
        {{ $t("MintSettings.advanced.title") }}
      </div>
      <div class="divider-line"></div>
    </div>

    <q-expansion-item
      dense
      dense-toggle
      class="text-left q-mb-md"
      :label="$t('MintSettings.advanced.actions.show_advanced.label')"
      :caption="$t('MintSettings.advanced.actions.show_advanced.description')"
    >
      <AdvancedFeatures />
    </q-expansion-item>
  </div>
</template>
<script lang="ts">
import { ref, defineComponent, onMounted, onBeforeUnmount } from "vue";
import { getShortUrl } from "src/js/wallet-helpers";
import AdvancedFeatures from "components/AdvancedFeatures.vue";
import { mapActions, mapState, mapWritableState } from "pinia";
import { useMintsStore, MintClass } from "src/stores/mints";
import { useWalletStore } from "src/stores/wallet";
import { useCameraStore } from "src/stores/camera";
import { map } from "underscore";
import { currentDateStr } from "src/js/utils";
import { useSettingsStore } from "src/stores/settings";
import { useNostrStore } from "src/stores/nostr";
import { useP2PKStore } from "src/stores/p2pk";
import { useWorkersStore } from "src/stores/workers";
import { useSwapStore } from "src/stores/swap";
import { useUiStore } from "src/stores/ui";
import { notifyError, notifyWarning } from "src/js/notify";
import { EventBus } from "../js/eventBus";
import AddMintDialog from "src/components/AddMintDialog.vue";

export default defineComponent({
  name: "MintSettings",
  mixins: [windowMixin],
  components: {
    AddMintDialog,
    AdvancedFeatures,
  },
  props: {},
  setup() {
    const addMintDiv = ref(null);

    const scrollToAddMintDiv = () => {
      if (addMintDiv.value) {
        // addMintDiv.value.scrollIntoView({ behavior: "smooth" });
        // const top = addMintDiv.value.offsetTop;
        const rect = addMintDiv.value.getBoundingClientRect();
        window.scrollTo({
          top: window.scrollY + rect.top,
          behavior: "smooth",
        });
      }
    };

    onMounted(() => {
      EventBus.on("scrollToAddMintDiv", scrollToAddMintDiv);
    });

    onBeforeUnmount(() => {
      EventBus.off("scrollToAddMintDiv", scrollToAddMintDiv);
    });
    return {
      addMintDiv,
    };
  },
  data: function () {
    return {
      activatingMintUrl: "",
    };
  },
  computed: {
    ...mapWritableState(useSettingsStore, ["getBitcoinPrice"]),
    ...mapState(useP2PKStore, ["p2pkKeys"]),
    ...mapState(useMintsStore, [
      "activeMintUrl",
      "activeUnit",
      "mints",
      "activeProofs",
    ]),
  },
  methods: {
    ...mapActions(useP2PKStore, ["generateKeypair", "showKeyDetails"]),
    ...mapActions(useMintsStore, [
      "removeMint",
      "activateMintUrl",
      "updateMint",
      "triggerMintInfoMotdChanged",
      "fetchMintInfo",
    ]),
    ...mapActions(useWalletStore, ["decodeRequest", "mintOnPaid"]),
    ...mapActions(useWorkersStore, ["clearAllWorkers"]),
    ...mapActions(useCameraStore, ["closeCamera", "showCamera"]),
    activateMintUrlInternal: async function (mintUrl) {
      this.activatingMintUrl = mintUrl;
      console.log(`Activating mint ${this.activatingMintUrl}`);
      try {
        await this.activateMintUrl(mintUrl, false, true);
      } catch (e) {
        console.log("#### Error activating mint:", e);
      } finally {
        this.activatingMintUrl = "";
      }
    },
    mintClass(mint) {
      return new MintClass(mint);
    },
    showMintInfo: async function (mint) {
      // Fetch fresh mint info before navigating
      this.activatingMintUrl = mint.url;
      try {
        const newMintInfo = await this.fetchMintInfo(mint);
        this.triggerMintInfoMotdChanged(newMintInfo, mint);
        this.mints.filter((m) => m.url === mint.url)[0].info = newMintInfo;
      } catch (error) {
        console.log("Failed to fetch mint info:", error);
      } finally {
        this.activatingMintUrl = "";
      }

      // Navigate to mint details page with mint URL as query parameter
      this.$router.push({
        path: "/mintdetails",
        query: { mintUrl: mint.url },
      });
    },
    getMintIconUrl: function (mint) {
      if (mint.info) {
        if (mint.info.icon_url) {
          return mint.info.icon_url;
        } else {
          return undefined;
        }
      } else {
        return undefined;
      }
    },
  },
  created: function () {},
});
</script>

<style>
@import "src/css/mintlist.css";

/* Add Mint Section Styles */
.add-mint-container {
  width: 100%;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  margin-bottom: 32px;
}

.add-mint-description {
  font-size: 14px;
  line-height: 24px;
  font-weight: 500;
  text-align: left;
  margin-bottom: 24px;
}

.add-mint-inputs {
  width: 100%;
  display: flex;
  flex-direction: column;
}

.mint-input {
  width: 100%;
  font-family: "Inter", sans-serif;
}

.mint-input .q-field__control {
  height: 54px;
  border-radius: 100px;
}

.mint-input .q-field__native,
.mint-input .q-field__input,
.mint-input .q-placeholder {
  font-family: "Inter", sans-serif;
}

.add-mint-actions {
  width: 100%;
  margin-top: 16px;
}

/* Section Divider */
.section-divider {
  display: flex;
  align-items: center;
  width: 100%;
  margin-bottom: 24px;
}

.divider-line {
  flex: 1;
  height: 1px;
  background-color: #48484a;
}

.divider-text {
  padding: 0 10px;
  font-size: 14px;
  font-weight: 600;
  color: #ffffff;
  text-transform: uppercase;
}
</style>
