<template>
  <q-header class="bg-transparent">
    <q-toolbar>
      <q-btn
        flat
        dense
        round
        icon="menu"
        color="primary"
        aria-label="Menu"
        @click="toggleLeftDrawer"
        :disable="uiStore.globalMutexLock"
      />
      <q-toolbar-title class="flex flex-center">
        <img
          :src="brandLogo"
          :alt="brandName"
          style="height: 100px; max-width: 400px; object-fit: contain"
        />
      </q-toolbar-title>
      <transition
        appear
        enter-active-class="animated wobble"
        leave-active-class="animated fadeOut"
      >
        <q-badge
          v-if="g.offline"
          color="red"
          text-color="black"
          class="q-mr-sm"
        >
          <span>{{ $t("MainHeader.offline.warning.text") }}</span>
        </q-badge>
      </transition>
      <q-badge
        v-if="isStaging()"
        color="yellow"
        text-color="black"
        class="q-mr-sm"
      >
        <span>{{ $t("MainHeader.staging.warning.text") }}</span>
      </q-badge>
      <!-- <q-badge color="yellow" text-color="black" class="q-mr-sm">
        <span v-if="!isStaging()">Beta</span>
        <span v-else>Staging – don't use with real funds!</span>
      </q-badge> -->
      <transition-group appear enter-active-class="animated pulse">
        <q-badge
          v-if="countdown > 0"
          color="negative"
          text-color="white"
          class="q-mr-sm"
          @click="reload"
        >
          {{ $t("MainHeader.reload.warning.text", { countdown }) }}
          <q-spinner
            v-if="countdown > 0"
            size="0.8em"
            :thickness="10"
            class="q-ml-sm"
            color="white"
          />
        </q-badge>
      </transition-group>
      <q-btn
        flat
        dense
        round
        size="0.8em"
        :icon="countdown > 0 ? 'close' : 'refresh'"
        :color="countdown > 0 ? 'negative' : 'primary'"
        aria-label="Refresh"
        @click="reload"
        :disable="uiStore.globalMutexLock && countdown === 0"
      >
      </q-btn>
    </q-toolbar>
  </q-header>

  <q-drawer v-model="leftDrawerOpen" bordered>
    <q-list>
      <q-item-label header>{{
        $t("MainHeader.menu.settings.title")
      }}</q-item-label>
      <q-item clickable to="/settings">
        <q-item-section avatar>
          <q-icon name="settings" />
        </q-item-section>
        <q-item-section>
          <q-item-label>{{
            $t("MainHeader.menu.settings.settings.title")
          }}</q-item-label>
          <q-item-label caption>{{
            $t("MainHeader.menu.settings.settings.caption")
          }}</q-item-label>
        </q-item-section>
      </q-item>
      <q-item-label header>{{
        $t("MainHeader.menu.terms.title")
      }}</q-item-label>
      <q-item clickable to="/terms">
        <q-item-section avatar>
          <q-icon name="gavel" />
        </q-item-section>
        <q-item-section>
          <q-item-label>{{
            $t("MainHeader.menu.terms.terms.title")
          }}</q-item-label>
          <q-item-label caption>{{
            $t("MainHeader.menu.terms.terms.caption")
          }}</q-item-label>
        </q-item-section>
      </q-item>
    </q-list>
  </q-drawer>
</template>

<script lang="ts">
import { defineComponent, ref, computed } from "vue";
import { useUiStore } from "src/stores/ui";
import { useI18n } from "vue-i18n";
import { getBrand, getBrandName, getActiveBrandId } from "src/utils/branding";

// Import brand logos statically so Vite can bundle them
import bitpointsLogo from "../assets/brands/bitpoints/bitpoints-logo.png";
import trailsLogo from "../assets/brands/trails/trails-logo.png";

export default defineComponent({
  name: "MainHeader",
  mixins: [windowMixin],
  components: {},
  setup() {
    const leftDrawerOpen = ref(false);
    const uiStore = useUiStore();
    const { t } = useI18n();
    const countdown = ref(0);
    let countdownInterval;
    
    // Get brand logo and name - use static imports for proper Vite bundling
    const brand = computed(() => getBrand());
    const brandLogo = computed(() => {
      const brandId = getActiveBrandId();
      // Return the statically imported logo based on active brand
      return brandId === "trails" ? trailsLogo : bitpointsLogo;
    });
    const brandName = computed(() => getBrandName());

    const toggleLeftDrawer = () => {
      leftDrawerOpen.value = !leftDrawerOpen.value;
    };

    const isStaging = () => {
      return location.host.includes("staging");
    };

    const reload = () => {
      if (countdown.value > 0) {
        uiStore.unlockMutex();
        clearInterval(countdownInterval);
        countdown.value = 0;
        return;
      }
      if (uiStore.globalMutexLock) return;
      uiStore.lockMutex();
      countdown.value = 3;
      countdownInterval = setInterval(() => {
        countdown.value--;
        if (countdown.value === 0) {
          clearInterval(countdownInterval);
          uiStore.unlockMutex();
          location.reload();
        }
      }, 1000);
    };

    return {
      leftDrawerOpen,
      toggleLeftDrawer,
      isStaging,
      reload,
      countdown,
      uiStore,
      brandLogo,
      brandName,
    };
  },
});
</script>
<style scoped>
.q-header {
  position: relative;
  z-index: auto;
  overflow-x: hidden;
}

.q-toolbar {
  flex-wrap: nowrap;
  min-height: 120px; /* Much larger height for bigger logo */
  padding: 15px 0;
}

.q-toolbar-title {
  flex: 0 1 auto; /* Allow title to shrink */
}

/* Make badges container handle overflow properly */
.q-toolbar > .q-badge {
  flex-shrink: 0;
}
</style>
