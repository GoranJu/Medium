<script>
import { GlButton, GlTruncate } from '@gitlab/ui';
import DastProfilesDrawer from 'ee/security_configuration/dast_profiles/dast_profiles_drawer/dast_profiles_drawer.vue';
import dastProfileConfiguratorMixin from 'ee/security_configuration/dast_profiles/dast_profiles_configurator_mixin';
import { SCANNER_TYPE, SITE_TYPE, DRAWER_VIEW_MODE } from 'ee/on_demand_scans/constants';
import SectionLayout from 'ee/security_orchestration/components/policy_editor/section_layout.vue';
import { DAST_PROFILE_I18N } from './constants';

export default {
  SITE_TYPE,
  SCANNER_TYPE,
  DRAWER_VIEW_MODE,
  i18n: { ...DAST_PROFILE_I18N },
  name: 'ProjectDastProfileSelector',
  components: {
    GlButton,
    GlTruncate,
    DastProfilesDrawer,
    SectionLayout,
  },
  mixins: [dastProfileConfiguratorMixin()],
  provide() {
    return {
      // rename namespacePath to projectPath for dastProfilesDrawer
      projectPath: this.namespacePath,
    };
  },
  inject: ['namespacePath'],
  data() {
    return {
      activeProfile: undefined,
      isSideDrawerOpen: false,
      selectedScannerProfileId: null,
      selectedSiteProfileId: null,
    };
  },
  computed: {
    scannerProfileButtonText() {
      return (
        this.selectedScannerProfile?.profileName ||
        this.$options.i18n.selectedScannerProfilePlaceholder
      );
    },
    siteProfileButtonText() {
      return (
        this.selectedSiteProfile?.profileName || this.$options.i18n.selectedSiteProfilePlaceholder
      );
    },
    profileIdInUse() {
      return this.isScannerProfile ? this.savedScannerProfileId : this.savedSiteProfileId;
    },
    selectedProfileId() {
      return this.isScannerProfile ? this.selectedScannerProfileId : this.selectedSiteProfileId;
    },
  },
  watch: {
    scannerProfiles() {
      this.hasDastProfileError();
    },
    siteProfiles() {
      this.hasDastProfileError();
    },
    selectedScannerProfile: 'updateProfiles',
    selectedSiteProfile: 'updateProfiles',
  },
  methods: {
    doesProfileExist(profiles = [], savedProfileName) {
      return profiles.some(({ profileName }) => profileName === savedProfileName);
    },
    hasDastProfileError() {
      if (this.isLoadingProfiles) {
        return;
      }

      const savedScannerProfileDoesNotExist =
        this.savedScannerProfileName &&
        !this.doesProfileExist(this.scannerProfiles, this.savedScannerProfileName);

      const savedSiteProfileDoesNotExist =
        this.savedSiteProfileName &&
        !this.doesProfileExist(this.siteProfiles, this.savedSiteProfileName);

      if (savedScannerProfileDoesNotExist || savedSiteProfileDoesNotExist) {
        this.$emit('error');
      }
    },
    updateProfiles() {
      this.$emit('profiles-selected', {
        scannerProfile: this.selectedScannerProfile?.profileName,
        siteProfile: this.selectedSiteProfile?.profileName,
      });
    },
  },
};
</script>

<template>
  <div class="gl-w-full">
    <section-layout class="gl-mb-3 gl-w-full gl-bg-white" :show-remove-button="false">
      <template #selector>
        <label class="gl-mb-0 gl-mr-4" for="scanner-profile">
          {{ $options.i18n.scanLabel }}
        </label>
      </template>
      <template #content>
        <gl-button
          id="scanner-profile"
          data-testid="scanner-profile-trigger"
          :disabled="failedToLoadProfiles"
          :loading="isLoadingProfiles"
          @click="
            openProfileDrawer({
              profileType: $options.SCANNER_TYPE,
              mode: $options.DRAWER_VIEW_MODE.READING_MODE,
            })
          "
        >
          <gl-truncate :text="scannerProfileButtonText" />
        </gl-button>
      </template>
    </section-layout>
    <section-layout class="gl-w-full gl-bg-white" :show-remove-button="false">
      <template #selector>
        <label class="gl-mb-0 gl-mr-4" for="site-profile">
          {{ $options.i18n.siteLabel }}
        </label>
      </template>
      <template #content>
        <gl-button
          id="site-profile"
          data-testid="site-profile-trigger"
          :disabled="failedToLoadProfiles"
          :loading="isLoadingProfiles"
          @click="
            openProfileDrawer({
              profileType: $options.SITE_TYPE,
              mode: $options.DRAWER_VIEW_MODE.READING_MODE,
            })
          "
        >
          <gl-truncate :text="siteProfileButtonText" />
        </gl-button>
      </template>
    </section-layout>

    <dast-profiles-drawer
      :active-profile="activeProfile"
      :full-path="namespacePath"
      :open="isSideDrawerOpen"
      :is-loading="isLoadingProfiles"
      :profiles="selectedProfiles"
      :profile-id-in-use="profileIdInUse"
      :selected-profile-id="selectedProfileId"
      @close-drawer="closeProfileDrawer"
      @reopen-drawer="reopenProfileDrawer"
      @select-profile="selectProfile"
      @profile-submitted="onScannerProfileCreated"
    />
  </div>
</template>
