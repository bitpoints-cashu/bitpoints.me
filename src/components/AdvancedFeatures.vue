<template>
  <div style="max-width: 800px; margin: 0 auto">
    <div class="q-pa-md">
      <div class="text-h6 q-mb-md">Advanced Features</div>

      <q-list bordered separator class="q-mb-md">
        <!-- Discover Mints over Nostr -->
        <q-item clickable v-ripple @click="openDiscoverMints">
          <q-item-section>
            <q-item-label class="text-weight-medium">Discover Mints</q-item-label>
            <q-item-label caption>
              Find recommended mints via Nostr relays
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-btn dense flat color="primary" icon="search" :loading="discoveringMints" />
          </q-item-section>
        </q-item>

        <q-item clickable v-ripple @click="openAddMintDialog">
          <q-item-section>
            <q-item-label class="text-weight-medium">Add Mint</q-item-label>
            <q-item-label caption>
              Add a new mint URL and fetch keys/keysets
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-btn dense flat color="primary" icon="add" />
          </q-item-section>
        </q-item>

        <q-item clickable v-ripple :disable="!activeMintUrl" @click="openActiveMintDetails">
          <q-item-section>
            <q-item-label class="text-weight-medium">Active Mint Details</q-item-label>
            <q-item-label caption>
              View information and manage the active mint
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-btn dense flat color="primary" icon="info" />
          </q-item-section>
        </q-item>

        <q-item>
          <q-item-section>
            <q-item-label class="text-weight-medium">Enable Receive Swaps</q-item-label>
            <q-item-label caption>
              Automatically offer to swap incoming tokens to a trusted mint
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-toggle v-model="enableReceiveSwaps" color="primary" />
          </q-item-section>
        </q-item>

        <q-item>
          <q-item-section>
            <q-item-label class="text-weight-medium">Use Multinut</q-item-label>
            <q-item-label caption>
              Pay across multiple mints when needed (experimental)
            </q-item-label>
          </q-item-section>
          <q-item-section side>
            <q-toggle v-model="multinutEnabled" color="primary" />
          </q-item-section>
        </q-item>
      </q-list>
      <q-dialog v-model="showDiscoverDialog" position="bottom">
        <q-card style="width: 100%; max-width: 700px">
          <q-card-section class="row items-center q-pb-none">
            <div class="text-h6">Discover Mints</div>
            <q-space />
            <q-btn icon="close" flat round dense v-close-popup />
          </q-card-section>
          <q-card-section>
            <div v-if="discoveringMints" class="q-pa-md text-center">
              <q-spinner color="primary" size="2em" />
            </div>
            <q-list v-else bordered separator>
              <q-item v-for="rec in mintRecommendations" :key="rec.url">
                <q-item-section>
                  <q-item-label class="text-weight-medium">{{ rec.url }}</q-item-label>
                  <q-item-label caption>Recommended by {{ rec.count }}</q-item-label>
                </q-item-section>
                <q-item-section side>
                  <q-btn dense flat color="primary" icon="add" @click="addDiscoveredMint(rec.url)" />
                </q-item-section>
              </q-item>
              <div v-if="mintRecommendations.length === 0" class="q-pa-md text-center text-grey">
                No recommendations found
              </div>
            </q-list>
          </q-card-section>
          <q-card-actions align="right">
            <q-btn flat color="primary" label="Close" v-close-popup />
          </q-card-actions>
        </q-card>
      </q-dialog>
    </div>
  </div>
  
</template>

<script lang="ts">
import { defineComponent, ref } from "vue";
import { mapState, mapWritableState } from "pinia";
import { useMintsStore } from "src/stores/mints";
import { useSettingsStore } from "src/stores/settings";
import { useRouter } from "vue-router";
import { useNostrStore } from "src/stores/nostr";

export default defineComponent({
  name: "AdvancedFeatures",
  computed: {
    ...mapState(useMintsStore, ["activeMintUrl"]),
    ...mapWritableState(useSettingsStore, [
      "enableReceiveSwaps",
      "multinutEnabled",
    ]),
    ...mapState(useNostrStore, ["mintRecommendations"]),
  },
  setup() {
    const router = useRouter();
    const nostrStore = useNostrStore();
    const openActiveMintDetails = function () {
      const mintsStore = useMintsStore();
      if (!mintsStore.activeMintUrl) return;
      router.push({
        path: "/mintdetails",
        query: { mintUrl: mintsStore.activeMintUrl },
      });
    };
    const openAddMintDialog = function () {
      const mintsStore = useMintsStore();
      mintsStore.showAddMintDialog = true;
    };
    const showDiscoverDialog = ref(false);
    const discoveringMints = ref(false);
    const openDiscoverMints = async function () {
      showDiscoverDialog.value = true;
      try {
        discoveringMints.value = true;
        await nostrStore.initNdkReadOnly();
        await nostrStore.fetchMints();
      } finally {
        discoveringMints.value = false;
      }
    };
    const addDiscoveredMint = async function (url: string) {
      const mintsStore = useMintsStore();
      await mintsStore.activateMintUrl(url, false, true);
      showDiscoverDialog.value = false;
    };
    return {
      openActiveMintDetails,
      openAddMintDialog,
      openDiscoverMints,
      addDiscoveredMint,
      showDiscoverDialog,
      discoveringMints,
    };
  },
});
</script>

<style scoped>
</style>
