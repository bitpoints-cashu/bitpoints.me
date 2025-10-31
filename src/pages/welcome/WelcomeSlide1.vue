<!-- src/components/WelcomeSlide1.vue -->
<template>
  <div class="q-pa-md flex flex-center">
    <div class="text-center">
      <transition appear enter-active-class="animated bounce">
        <img
          :src="brandLogo"
          :alt="brandName"
          class="q-my-lg"
          style="max-width: 250px; height: auto"
        />
      </transition>
      <h2 class="q-mt-md">{{ welcomeTitle }}</h2>
      <div class="text-left">
        <p class="q-mt-sm">{{ welcomeText }}</p>
        <q-expansion-item
          dense
          dense-toggle
          class="text-left q-mt-lg"
          :label="$t('WelcomeSlide1.actions.more.label')"
        >
          <i18n-t keypath="WelcomeSlide1.p1.text" tag="p" class="q-mt-md">
            <template v-slot:link>
              <a href="https://cashu.space" target="_blank">{{
                $t("WelcomeSlide1.p1.link.text")
              }}</a>
            </template>
          </i18n-t>
          <i18n-t keypath="WelcomeSlide1.p2.text" tag="p" class="q-mt-md" />
          <i18n-t keypath="WelcomeSlide1.p3.text" tag="p" class="q-mt-md" />
          <i18n-t keypath="WelcomeSlide1.p4.text" tag="p" class="q-mt-md" />
        </q-expansion-item>
        <q-checkbox
          v-model="welcomeStore.termsAccepted"
          :label="
            $t(
              'WelcomeSlide1.inputs.checkbox.label',
              'I have read and agree to the terms'
            )
          "
          class="q-mt-lg"
        />
      </div>
    </div>
  </div>
</template>

<script lang="ts">
import { computed } from "vue";
import { useI18n } from "vue-i18n";
import { useWelcomeStore } from "src/stores/welcome";
import { getBrand, getBrandName, getActiveBrandId } from "src/utils/branding";

// Import brand logos statically so Vite can bundle them
import bitpointsLogo from "../../assets/brands/bitpoints/bitpoints-logo.png";
import trailsLogo from "../../assets/brands/trails/trails-logo.png";

export default {
  name: "WelcomeSlide1",
  setup() {
    const welcomeStore = useWelcomeStore();
    const { t } = useI18n();
    const brand = computed(() => getBrand());
    
    // Get brand logo and name - use static imports for proper Vite bundling
    const brandLogo = computed(() => {
      const brandId = getActiveBrandId();
      return brandId === "trails" ? trailsLogo : bitpointsLogo;
    });
    const brandName = computed(() => getBrandName());
    
    // Dynamic welcome text based on brand
    const welcomeTitle = computed(() => {
      return `Welcome to ${brand.value.shortName}`;
    });
    const welcomeText = computed(() => {
      if (getActiveBrandId() === "trails") {
        return "Your personal Bitcoin-backed rewards points. Receive and manage your points securely.";
      }
      return t("WelcomeSlide1.text");
    });
    
    return {
      welcomeStore,
      brandLogo,
      brandName,
      welcomeTitle,
      welcomeText,
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
</style>
