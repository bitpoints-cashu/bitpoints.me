<!-- src/pages/WelcomePage.vue -->
<template>
  <q-page class="welcome-page">
    <q-card class="q-pa-none full-height">
      <q-carousel
        v-model="welcomeStore.currentSlide"
        animated
        control-color="primary"
        class="flex-1"
      >
        <q-carousel-slide :name="0">
          <WelcomeSlide1 />
        </q-carousel-slide>
        <q-carousel-slide :name="1">
          <WelcomeSlide2 />
        </q-carousel-slide>
      </q-carousel>

      <div class="q-pa-md flex justify-between">
        <q-btn
          flat
          icon="arrow_left"
          :label="$t('WelcomePage.actions.previous.label')"
          v-if="welcomeStore.canGoPrev"
          @click="welcomeStore.goToPrevSlide"
        />
        <!-- language selector -->
        <div
          class="q-ml-md"
          v-if="!welcomeStore.canGoPrev"
          style="position: relative; top: -5px"
        >
          <q-select
            v-model="selectedLanguage"
            :options="languageOptions"
            emit-value
            dense
            map-options
            @update:model-value="changeLanguage"
            style="max-width: 200px; max-height: 20px"
          />
        </div>
        <q-space />
        <q-btn
          flat
          icon="arrow_right"
          :label="$t('WelcomePage.actions.next.label')"
          :disable="!welcomeStore.canProceed"
          @click="welcomeStore.goToNextSlide"
        />
      </div>
    </q-card>
  </q-page>
</template>

<script lang="ts">
import { onMounted, ref, watch } from "vue";
import { useRouter } from "vue-router";
import { useWelcomeStore } from "src/stores/welcome";
import { useStorageStore } from "src/stores/storage";
import WelcomeSlide1 from "./welcome/WelcomeSlide1.vue";
import WelcomeSlide2 from "./welcome/WelcomeSlide2.vue";

export default {
  name: "WelcomePage",
  components: {
    WelcomeSlide1,
    WelcomeSlide2,
  },
  data() {
    return {
      selectedLanguage: "",
      languageOptions: [
        { label: "English", value: "en-US" },
        { label: "Español", value: "es-ES" },
        { label: "Italiano", value: "it-IT" },
        { label: "Deutsch", value: "de-DE" },
        { label: "Français", value: "fr-FR" },
        { label: "Svenska", value: "sv-SE" },
        { label: "Ελληνικά", value: "el-GR" },
        { label: "Türkçe", value: "tr-TR" },
        { label: "ไทย", value: "th-TH" },
        { label: "العربية", value: "ar-SA" },
        { label: "中文", value: "zh-CN" },
        { label: "日本語", value: "ja-JP" },
      ],
    };
  },
  methods: {
    changeLanguage(locale) {
      // Set the i18n locale
      this.$i18n.locale = locale;

      // Store the selected language in localStorage
      localStorage.setItem("cashu.language", locale);
    },
  },
  created() {
    // Set the initial selected language based on the current locale or from storage
    this.selectedLanguage =
      this.languageOptions.find(
        (option) => option.value === this.$i18n.locale || navigator.language
      )?.label || "Language";
  },
  setup() {
    const router = useRouter();
    const welcomeStore = useWelcomeStore();
    const storageStore = useStorageStore();
    const fileUpload = ref(null);

    const onChangeFileUpload = () => {
      const file = fileUpload.value.files[0];
      if (file) readFile(file);
    };

    const readFile = (file) => {
      const reader = new FileReader();
      reader.onload = (f) => {
        const backup = JSON.parse(f.target.result);
        storageStore.restoreFromBackup(backup);
      };
      reader.readAsText(file);
    };

    const dragFile = (ev) => {
      const file = ev.dataTransfer.files[0];
      if (file) readFile(file);
    };

    onMounted(() => {
      // Check if welcome is needed
      if (!welcomeStore.showWelcome) {
        // User has already completed welcome, redirect to wallet
        router.push("/");
        return;
      }

      welcomeStore.initializeWelcome();
    });

    // Watch for welcome completion and navigate to wallet
    watch(
      () => welcomeStore.showWelcome,
      (newValue) => {
        if (!newValue) {
          // Welcome completed, navigate to wallet
          router.push("/");
        }
      }
    );

    return {
      welcomeStore,
      fileUpload,
      onChangeFileUpload,
      dragFile,
    };
  },
};
</script>

<style scoped>
.welcome-page {
  height: 100vh;
  display: flex;
  flex-direction: column;
}

.full-height {
  height: 100%;
  display: flex;
  flex-direction: column;
}

.q-card {
  display: flex;
  flex-direction: column;
  height: 100%;
}

.q-carousel {
  flex: 1;
}

.custom-navigation {
  display: flex;
  justify-content: space-between;
  padding: 16px;
}
</style>
