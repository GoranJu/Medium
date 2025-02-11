<script>
import { GlAlert, GlButton, GlIcon, GlSprintf } from '@gitlab/ui';
import { joinPaths } from '~/lib/utils/url_utility';
import { s__ } from '~/locale';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { NEW_POLICY_BUTTON_TEXT } from '../constants';
import InvalidPoliciesBanner from './banners/invalid_policies_banner.vue';
import ExceedingActionsBanner from './banners/exceeding_actions_banner.vue';
import DeprecatedCustomScanBanner from './banners/deprecated_custom_scan_banner.vue';
import ProjectModal from './project_modal.vue';

export default {
  BANNER_STORAGE_KEY: 'security_policies_scan_result_name_change',
  components: {
    DeprecatedCustomScanBanner,
    ExceedingActionsBanner,
    GlAlert,
    GlButton,
    GlIcon,
    GlSprintf,
    InvalidPoliciesBanner,
    ProjectModal,
    PageHeading,
  },
  inject: [
    'assignedPolicyProject',
    'disableSecurityPolicyProject',
    'disableScanPolicyUpdate',
    'documentationPath',
    'newPolicyPath',
    'namespaceType',
  ],
  props: {
    hasInvalidPolicies: {
      type: Boolean,
      required: true,
    },
    hasDeprecatedCustomScanPolicies: {
      type: Boolean,
      required: true,
    },
    hasExceedingActionLimitPolicies: {
      type: Boolean,
      required: true,
    },
  },
  i18n: {
    title: s__('SecurityOrchestration|Policies'),
    subtitle: {
      [NAMESPACE_TYPES.GROUP]: s__(
        'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for all projects in this group.',
      ),
      [NAMESPACE_TYPES.PROJECT]: s__(
        'SecurityOrchestration|Enforce %{linkStart}security policies%{linkEnd} for this project.',
      ),
    },
    newPolicyButtonText: NEW_POLICY_BUTTON_TEXT,
    editPolicyProjectButtonText: s__('SecurityOrchestration|Edit policy project'),
    viewPolicyProjectButtonText: s__('SecurityOrchestration|View policy project'),
  },
  data() {
    return {
      projectIsBeingLinked: false,
      showAlert: false,
      alertVariant: '',
      alertText: '',
      modalVisible: false,
    };
  },
  computed: {
    hasAssignedPolicyProject() {
      return Boolean(this.assignedPolicyProject?.id);
    },
    securityPolicyProjectPath() {
      return joinPaths('/', this.assignedPolicyProject?.fullPath);
    },
  },
  methods: {
    updateAlertText({ text, variant, hasPolicyProject }) {
      this.projectIsBeingLinked = false;

      if (text) {
        this.showAlert = true;
        this.alertVariant = variant;
        this.alertText = text;
      }
      this.$emit('update-policy-list', { hasPolicyProject, shouldUpdatePolicyList: true });
    },
    isUpdatingProject() {
      this.projectIsBeingLinked = true;
      this.showAlert = false;
      this.alertVariant = '';
      this.alertText = '';
    },
    dismissAlert() {
      this.showAlert = false;
    },
    showNewPolicyModal() {
      this.modalVisible = true;
    },
  },
};
</script>
<template>
  <div>
    <gl-alert
      v-if="showAlert"
      class="gl-mt-3"
      :dismissible="true"
      :variant="alertVariant"
      data-testid="error-alert"
      @dismiss="dismissAlert"
    >
      {{ alertText }}
    </gl-alert>

    <page-heading :heading="$options.i18n.title">
      <template #description>
        <gl-sprintf :message="$options.i18n.subtitle[namespaceType]">
          <template #link="{ content }">
            <gl-button
              class="!gl-pb-1"
              variant="link"
              :href="documentationPath"
              target="_blank"
              data-testid="more-information-link"
            >
              {{ content }}
            </gl-button>
          </template>
        </gl-sprintf>
      </template>

      <template #actions>
        <gl-button
          v-if="!disableSecurityPolicyProject"
          data-testid="edit-project-policy-button"
          :loading="projectIsBeingLinked"
          @click="showNewPolicyModal"
        >
          {{ $options.i18n.editPolicyProjectButtonText }}
        </gl-button>
        <gl-button
          v-else-if="hasAssignedPolicyProject"
          data-testid="view-project-policy-button"
          target="_blank"
          :href="securityPolicyProjectPath"
        >
          <gl-icon name="external-link" />
          {{ $options.i18n.viewPolicyProjectButtonText }}
        </gl-button>
        <gl-button
          v-if="!disableScanPolicyUpdate"
          data-testid="new-policy-button"
          variant="confirm"
          :href="newPolicyPath"
        >
          {{ $options.i18n.newPolicyButtonText }}
        </gl-button>
      </template>
    </page-heading>

    <project-modal
      :visible="modalVisible"
      @close="modalVisible = false"
      @project-updated="updateAlertText"
      @updating-project="isUpdatingProject"
    />

    <!-- <breaking-changes-banner class="gl-mt-3 gl-mb-6" /> -->
    <deprecated-custom-scan-banner v-if="hasDeprecatedCustomScanPolicies" class="gl-mb-6 gl-mt-3" />

    <invalid-policies-banner v-if="hasInvalidPolicies" />

    <exceeding-actions-banner v-if="hasExceedingActionLimitPolicies" class="gl-mb-6" />
  </div>
</template>
