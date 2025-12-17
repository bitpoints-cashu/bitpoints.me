<!-- src/components/WelcomeSlide2.vue -->
<template>
  <!-- Only show this slide for PWA/web browsers, not for Android native app -->
  <div v-if="!$parent.isNativeApp" class="q-pa-md flex flex-center">
    <div class="text-center relative-position">
      <q-icon name="download_for_offline" size="4em" color="primary" />
      <h2 class="q-mt-xl">Install PWA</h2>
      <div class="text-left">
        <p class="q-mt-md">
          To install this app on your device, follow these steps:
        </p>
        <p class="q-mt-md">
          1. Look for the install prompt in your browser<br />
          2. Click "Install" or "Add to Home Screen"<br />
          3. The app will be added to your device
        </p>
      </div>
    </div>
  </div>
</template>

<script lang="ts">
export default {
  name: "WelcomeSlide2",
};
</script>

<style scoped>
.relative-position {
  position: relative;
}
.instruction {
  display: flex;
  align-items: center;
  justify-content: center;
  margin-bottom: 1rem;
  color: #4a4a4a; /* Dark gray for readability */
}
.instruction span {
  margin-left: 0.5rem;
  font-size: 1rem;
}
h2 {
  font-weight: bold;
}
h3 {
  font-weight: bold;
}
h6 {
  font-weight: bold;
  margin-top: 1rem;
  margin-bottom: 0.5rem;
}
p {
  font-size: large;
  color: #4a4a4a; /* Dark gray for readability */
}
.sub-instruction {
  margin-left: 0.5rem;
  color: #4a4a4a; /* Dark gray for readability */
}
strong {
  color: #2c2c2c; /* Darker for emphasis */
}
</style>
