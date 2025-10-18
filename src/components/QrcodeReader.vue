<script lang="ts">
import QrScanner from "qr-scanner";
import { URDecoder } from "@gandlaf21/bc-ur";
import { useCameraStore } from "src/stores/camera";
import { mapActions, mapState, mapWritableState } from "pinia";
import { useUiStore } from "src/stores/ui";

export default {
  emits: ["decode"],
  data(): {
    qrScanner: QrScanner | null;
    urDecoder: URDecoder | null;
    urDecoderProgress: number;
    cameraWorking: boolean;
  } {
    return {
      qrScanner: null,
      urDecoder: null,
      urDecoderProgress: 0,
      cameraWorking: false,
    };
  },
  async mounted() {
    try {
      // Request camera permission first for Android compatibility
      const hasPermission = await this.requestCameraPermission();
      if (!hasPermission) {
        console.error('Camera permission denied');
        this.$q.notify({
          type: 'negative',
          message: 'Camera permission is required to scan QR codes',
          position: 'top',
        });
        return;
      }

      this.qrScanner = new QrScanner(
        this.$refs.cameraEl as HTMLVideoElement,
        (result: QrScanner.ScanResult) => {
          this.handleResult(result);
        },
        {
          returnDetailedScanResult: true,
          highlightScanRegion: true,
          highlightCodeOutline: true,
          onDecodeError: (error) => {
            console.debug('QR decode error:', error);
          },
        }
      );

      await this.qrScanner.start();
      this.urDecoder = new URDecoder();
      this.cameraWorking = true;
      console.log('✅ Camera started successfully');
    } catch (error) {
      console.error('❌ Failed to start camera:', error);
      this.$q.notify({
        type: 'negative',
        message: `Camera error: ${error}. Please check permissions in Settings.`,
        position: 'top',
        timeout: 5000,
      });
    }
  },
  computed: {
    ...mapState(useCameraStore, ["camera", "hasCamera"]),
    canPasteFromClipboard: function () {
      return (
        window.isSecureContext &&
        navigator.clipboard &&
        navigator.clipboard.readText
      );
    },
  },
  methods: {
    ...mapActions(useCameraStore, ["closeCamera", "showCamera"]),
    async requestCameraPermission() {
      try {
        // First try the web API approach (works on most platforms)
        console.log('📷 Requesting camera permission via getUserMedia...');
        const stream = await navigator.mediaDevices.getUserMedia({
          video: {
            facingMode: 'environment',
            width: { ideal: 1280 },
            height: { ideal: 720 }
          }
        });

        // Close the stream immediately after getting permission
        stream.getTracks().forEach(track => track.stop());
        console.log('✅ Camera permission granted via getUserMedia');
        return true;

      } catch (webError) {
        console.warn('❌ getUserMedia failed, trying Capacitor Camera plugin...', webError);

        try {
          // Fallback to Capacitor Camera plugin
          const { Camera } = await import('@capacitor/camera');

          // Check current permissions
          const permissions = await Camera.checkPermissions();
          console.log('📷 Current camera permissions:', permissions);

          if (permissions.camera === 'granted') {
            console.log('✅ Camera permission already granted via Capacitor');
            return true;
          }

          // Request camera permission
          const requestResult = await Camera.requestPermissions();
          console.log('📷 Camera permission request result:', requestResult);

          if (requestResult.camera === 'granted') {
            console.log('✅ Camera permission granted via Capacitor');
            return true;
          } else {
            console.error('❌ Camera permission denied via Capacitor:', requestResult);
            return false;
          }
        } catch (capacitorError) {
          console.error('❌ Capacitor Camera plugin also failed:', capacitorError);
          return false;
        }
      }
    },
    handleResult(result: QrScanner.ScanResult) {
      // if this is a multipart-qr code, do not yet emit
      if (result.data.toLowerCase().startsWith("ur:")) {
        this.urDecoder?.receivePart(result.data);
        this.urDecoderProgress =
          this.urDecoder?.estimatedPercentComplete() || 0;
        if (this.urDecoder?.isComplete() && this.urDecoder?.isSuccess()) {
          const ur = this.urDecoder?.resultUR();
          const decoded = ur.decodeCBOR();
          this.$emit("decode", decoded.toString());
          this.qrScanner?.stop();
          // Blur any focused input to prevent keyboard
          (document.activeElement as HTMLElement)?.blur();
          this.urDecoderProgress = 0;
        }
      } else {
        this.$emit("decode", result.data);
        this.qrScanner?.stop();
        // Blur any focused input to prevent keyboard
        (document.activeElement as HTMLElement)?.blur();
      }
    },
    pasteToParseDialog: async function () {
      const text = await useUiStore().pasteFromClipboard();
      if (text) {
        this.$emit("decode", text);
      }
    },
    async retryCameraPermission() {
      console.log('🔄 Retrying camera permission...');
      const hasPermission = await this.requestCameraPermission();
      if (hasPermission) {
        try {
          this.qrScanner = new QrScanner(
            this.$refs.cameraEl as HTMLVideoElement,
            (result: QrScanner.ScanResult) => {
              this.handleResult(result);
            },
            {
              returnDetailedScanResult: true,
              highlightScanRegion: true,
              highlightCodeOutline: true,
              onDecodeError: (error) => {
                console.debug('QR decode error:', error);
              },
            }
          );

          await this.qrScanner.start();
          this.cameraWorking = true;
          this.$q.notify({
            type: 'positive',
            message: 'Camera started successfully!',
            position: 'top',
          });
        } catch (error) {
          console.error('❌ Failed to start camera after permission:', error);
          this.$q.notify({
            type: 'negative',
            message: `Camera error: ${error}`,
            position: 'top',
          });
        }
      } else {
        this.$q.notify({
          type: 'negative',
          message: 'Camera permission denied. Please enable in Settings.',
          position: 'top',
        });
      }
    },
  },
  unmounted() {
    try {
      if (this.qrScanner) {
        this.qrScanner.stop();
        this.qrScanner.destroy();
      }
    } catch (error) {
      console.warn('Error cleaning up camera:', error);
    }
  },
};
</script>
<template>
  <q-card>
    <div class="text-center">
      <div>
        <video ref="cameraEl" style="width: 100%"></video>
      </div>
      <div>
        <div class="row q-justify-center">
          <q-linear-progress
            rounded
            size="30px"
            v-if="urDecoderProgress > 0"
            :value="urDecoderProgress"
            :indeterminate="urDecoderProgress === 0"
            class="q-mt-none"
            color="secondary"
          >
            <div class="absolute-full flex flex-center">
              <q-badge
                color="white"
                text-color="secondary"
                style="font-size: 1rem; padding: 5px"
                class="text-weight-bold"
                :label="
                  $t('QrcodeReader.progress.text', {
                    percentage: $t('QrcodeReader.progress.percentage', {
                      percentage: Math.round(urDecoderProgress * 100),
                    }),
                    addon:
                      urDecoderProgress > 0.9
                        ? $t('QrcodeReader.progress.keep_scanning_text')
                        : '',
                  })
                "
              />
            </div>
          </q-linear-progress>
        </div>
      </div>
    </div>
    <div class="row q-my-sm">
      <q-btn
        unelevated
        v-if="canPasteFromClipboard"
        @click="pasteToParseDialog"
      >
        <q-icon name="content_paste" class="q-mr-sm" />
        {{ $t("QrcodeReader.actions.paste.label") }}</q-btn
      >
      <q-btn
        v-if="!cameraWorking"
        @click="retryCameraPermission"
        color="primary"
        class="q-ml-sm"
      >
        <q-icon name="camera_alt" class="q-mr-sm" />
        Grant Camera Permission
      </q-btn>
      <q-btn flat round icon="close" color="grey" @click="closeCamera" class="q-ml-auto">
        <q-tooltip>Close</q-tooltip>
      </q-btn>
    </div>
  </q-card>
</template>
