<script>
import { GlEmptyState } from '@gitlab/ui';
import { debounce } from 'lodash';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import { setUrlFragment, queryToObject } from '~/lib/utils/url_utility';
import { s__, __ } from '~/locale';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { extractPolicyContent } from 'ee/security_orchestration/components/utils';
import {
  ACTION_SECTION_DISABLE_ERROR,
  ACTIONS_LABEL,
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  PARSING_ERROR_MESSAGE,
  SECURITY_POLICY_ACTIONS,
} from '../constants';
import { doesFileExist, getMergeRequestConfig, policyBodyToYaml, policyToYaml } from '../utils';
import EditorLayout from '../editor_layout.vue';
import DisabledSection from '../disabled_section.vue';
import ActionSection from './action/action_section.vue';
import RuleSection from './rule/rule_section.vue';
import { createPolicyObject, getInitialPolicy } from './utils';
import {
  CONDITIONS_LABEL,
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT,
} from './constants';

export default {
  ACTION: 'actions',
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  i18n: {
    ACTION_SECTION_DISABLE_ERROR,
    ACTIONS_LABEL,
    CONDITIONS_LABEL,
    PARSING_ERROR_MESSAGE,
    notOwnerButtonText: __('Learn more'),
    createMergeRequest: s__('SecurityOrchestration|Update via merge request'),
    configurationTitle: s__('SecurityOrchestration|Additional configuration'),
  },
  components: {
    ActionSection,
    DisabledSection,
    GlEmptyState,
    EditorLayout,
    RuleSection,
    SkipCiSelector,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: [
    'disableScanPolicyUpdate',
    'namespacePath',
    'policyEditorEmptyStateSvgPath',
    'scanPolicyDocumentationPath',
  ],
  props: {
    assignedPolicyProject: {
      type: Object,
      required: true,
    },
    existingPolicy: {
      type: Object,
      required: false,
      default: null,
    },
    isCreating: {
      type: Boolean,
      required: true,
    },
    isDeleting: {
      type: Boolean,
      required: true,
    },
    isEditing: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    let yamlEditorValue;

    if (this.existingPolicy) {
      yamlEditorValue = policyToYaml(
        this.existingPolicy,
        POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
      );
    } else {
      const manifest = this.glFeatures.securityPoliciesNewYamlFormat
        ? DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT
        : DEFAULT_PIPELINE_EXECUTION_POLICY;

      yamlEditorValue = getInitialPolicy(manifest, queryToObject(window.location.search));
    }

    const { policy, parsingError } = createPolicyObject(yamlEditorValue);

    return {
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'pipeline-execution-policy-editor',
      ),
      disableSubmit: false,
      mode: EDITOR_MODE_RULE,
      parsingError,
      policy,
      yamlEditorValue,
    };
  },
  computed: {
    hasSkipCiConfiguration() {
      return this.glFeatures.securityPoliciesSkipCi;
    },
    originalName() {
      return this.existingPolicy?.name;
    },
    strategy() {
      return this.policy?.pipeline_config_strategy || '';
    },
    content() {
      return this.policy?.content || {};
    },
  },
  watch: {
    content(newVal) {
      this.handleFileValidation(newVal);
    },
  },
  mounted() {
    if (this.existingPolicy) {
      this.handleFileValidation(this.existingPolicy?.content);
    }
  },
  created() {
    this.handleFileValidation = debounce(this.doesFileExist, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.handleFileValidation.cancel();
  },
  methods: {
    changeEditorMode(mode) {
      this.mode = mode;
    },
    async handleModifyPolicy(action) {
      const extraMergeRequestInput = getMergeRequestConfig(queryToObject(window.location.search), {
        namespacePath: this.namespacePath,
      });

      /**
       * backend only accepts the old format
       * policy body is extracted
       * and policy type is added to a policy body
       */
      const type = POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter;
      const policy = extractPolicyContent({ manifest: this.yamlEditorValue, type, withType: true });

      const payload = this.glFeatures.securityPoliciesNewYamlFormat
        ? policyBodyToYaml(policy)
        : this.yamlEditorValue;

      this.$emit('save', { action, extraMergeRequestInput, policy: payload });
    },
    async doesFileExist(value) {
      const { project, ref = null, file } = value?.include?.[0] || {};

      try {
        const exists = await doesFileExist({
          fullPath: project,
          filePath: file,
          ref,
        });

        this.disableSubmit = !exists;
      } catch {
        this.disableSubmit = true;
      }
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateYaml(manifest) {
      const { policy, parsingError } = createPolicyObject(manifest);

      this.yamlEditorValue = manifest;
      this.parsingError = parsingError;
      this.policy = policy;
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(
        policy,
        POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
      );
    },
  },
};
</script>

<template>
  <editor-layout
    v-if="!disableScanPolicyUpdate"
    :custom-save-button-text="$options.i18n.createMergeRequest"
    :is-editing="isEditing"
    :is-removing-policy="isDeleting"
    :is-updating-policy="isCreating"
    :policy="policy"
    :yaml-editor-value="yamlEditorValue"
    @remove-policy="handleModifyPolicy($options.SECURITY_POLICY_ACTIONS.REMOVE)"
    @save-policy="handleModifyPolicy()"
    @update-editor-mode="changeEditorMode"
    @update-property="handleUpdateProperty"
    @update-yaml="handleUpdateYaml"
  >
    <template #rules>
      <disabled-section data-testid="disabled-rule">
        <template #title>
          <h4>{{ $options.i18n.CONDITIONS_LABEL }}</h4>
        </template>
        <rule-section class="gl-mb-4" />
      </disabled-section>
    </template>

    <template #actions-first>
      <disabled-section
        :disabled="parsingError.actions"
        :error="$options.i18n.ACTION_SECTION_DISABLE_ERROR"
        data-testid="disabled-action"
      >
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>
        <action-section
          class="security-policies-bg-subtle gl-mb-4 gl-rounded-base gl-p-5"
          :action="content"
          :does-file-exist="!disableSubmit"
          :strategy="strategy"
          :suffix="policy.suffix"
          @changed="handleUpdateProperty"
        />
      </disabled-section>
    </template>

    <template v-if="hasSkipCiConfiguration" #settings>
      <disabled-section :disabled="false">
        <template #title>
          <h4>{{ $options.i18n.configurationTitle }}</h4>
        </template>

        <skip-ci-selector :skip-ci-configuration="policy.skip_ci" @changed="handleUpdateProperty" />
      </disabled-section>
    </template>
  </editor-layout>

  <gl-empty-state
    v-else
    :description="$options.i18n.notOwnerDescription"
    :primary-button-link="documentationPath"
    :primary-button-text="$options.i18n.notOwnerButtonText"
    :svg-path="policyEditorEmptyStateSvgPath"
    :svg-height="null"
    title=""
  />
</template>
