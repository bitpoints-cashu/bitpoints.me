<template>
  <div v-if="unclaimedCount > 0" class="ecash-claim-banner">
    <q-banner class="bg-positive text-white" rounded>
      <template v-slot:avatar>
        <q-icon name="bluetooth" size="md" />
      </template>

      <div class="banner-content">
        <div class="text-h6">
          {{ unclaimedCount }} Ecash Token{{ unclaimedCount !== 1 ? 's' : '' }} Received
        </div>
        <div class="text-caption">
          Total: {{ unclaimedValue }} sats via Bluetooth
        </div>
      </div>

      <template v-slot:action>
        <q-btn
          flat
          label="Claim All"
          @click="claimAll"
          :loading="claiming"
        />
        <q-btn
          flat
          icon="expand_more"
          @click="showDetails = !showDetails"
        />
      </template>
    </q-banner>

    <!-- Details expansion -->
    <q-slide-transition>
      <div v-if="showDetails" class="q-mt-sm">
        <q-card>
          <q-list separator>
            <q-item v-for="token in unclaimedTokens" :key="token.id">
              <q-item-section avatar>
                <q-avatar color="primary" text-color="white">
                  {{ token.amount }}
                </q-avatar>
              </q-item-section>

              <q-item-section>
                <q-item-label>
                  {{ token.amount }} {{ token.unit }}
                </q-item-label>
                <q-item-label caption>
                  From: {{ formatNpub(token.sender) }}
                </q-item-label>
                <q-item-label caption v-if="token.memo">
                  "{{ token.memo }}"
                </q-item-label>
                <q-item-label caption class="text-grey-6">
                  {{ formatTimestamp(token.timestamp) }}
                </q-item-label>
              </q-item-section>

              <q-item-section side>
                <q-btn
                  round
                  dense
                  flat
                  icon="download"
                  color="primary"
                  @click="claimSingle(token.id)"
                  :loading="claimingTokens.has(token.id)"
                >
                  <q-tooltip>Claim Token</q-tooltip>
                </q-btn>
              </q-item-section>
            </q-item>
          </q-list>
        </q-card>
      </div>
    </q-slide-transition>
  </div>
</template>

<script lang="ts">
import { defineComponent, ref, computed } from 'vue';
import { useBluetoothStore } from 'src/stores/bluetooth';
import { notifySuccess, notifyError } from 'src/js/notify';

export default defineComponent({
  name: 'EcashClaimNotification',

  setup() {
    const bluetoothStore = useBluetoothStore();
    const showDetails = ref(false);
    const claiming = ref(false);
    const claimingTokens = ref(new Set<string>());

    const unclaimedTokens = computed(() =>
      bluetoothStore.unclaimedTokens.filter(t => !t.claimed)
    );

    const unclaimedCount = computed(() => unclaimedTokens.value.length);

    const unclaimedValue = computed(() =>
      unclaimedTokens.value
        .filter(t => t.unit === 'sat')
        .reduce((sum, t) => sum + t.amount, 0)
    );

    const formatNpub = (npub: string): string => {
      if (!npub) return 'Unknown';
      return npub.substring(0, 12) + '...' + npub.substring(npub.length - 6);
    };

    const formatTimestamp = (timestamp: number): string => {
      const date = new Date(timestamp);
      const now = Date.now();
      const diff = now - timestamp;

      if (diff < 60000) return 'Just now';
      if (diff < 3600000) return `${Math.floor(diff / 60000)}m ago`;
      if (diff < 86400000) return `${Math.floor(diff / 3600000)}h ago`;

      return date.toLocaleDateString();
    };

    const claimSingle = async (tokenId: string) => {
      claimingTokens.value.add(tokenId);

      try {
        const success = await bluetoothStore.claimToken(tokenId);
        if (success) {
          notifySuccess('Token claimed successfully!');
        }
      } catch (e) {
        console.error('Failed to claim token:', e);
        notifyError('Failed to claim token');
      } finally {
        claimingTokens.value.delete(tokenId);
        claimingTokens.value = new Set(claimingTokens.value);  // Trigger reactivity
      }
    };

    const claimAll = async () => {
      claiming.value = true;

      try {
        await bluetoothStore.autoClaimTokens();
        notifySuccess('All tokens claimed!');
        showDetails.value = false;
      } catch (e) {
        console.error('Failed to claim tokens:', e);
        notifyError('Some tokens could not be claimed');
      } finally {
        claiming.value = false;
      }
    };

    return {
      bluetoothStore,
      showDetails,
      claiming,
      claimingTokens,
      unclaimedTokens,
      unclaimedCount,
      unclaimedValue,
      formatNpub,
      formatTimestamp,
      claimSingle,
      claimAll,
    };
  },
});
</script>

<style scoped>
.ecash-claim-banner {
  margin-bottom: 1rem;
}

.banner-content {
  flex-grow: 1;
}
</style>




