<script>
import { GlEmptyState, GlButton, GlTooltipDirective } from '@gitlab/ui';
import { setUrlFragment } from '~/lib/utils/url_utility';
import { __, s__, sprintf, n__ } from '~/locale';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getGroupProjectsCount from 'ee/security_orchestration/graphql/queries/get_group_project_count.query.graphql';
import {
  checkForPerformanceRisk,
  hasScheduledRule,
  isGroup,
  extractPolicyContent,
} from 'ee/security_orchestration/components/utils';
import OverloadWarningModal from 'ee/security_orchestration/components/overload_warning_modal.vue';
import {
  DEFAULT_SKIP_SI_CONFIGURATION,
  POLICY_TYPE_COMPONENT_OPTIONS,
} from 'ee/security_orchestration/components/constants';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import {
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  PARSING_ERROR_MESSAGE,
  SECURITY_POLICY_ACTIONS,
  ACTIONS_LABEL,
  ADD_ACTION_LABEL,
  ACTION_SECTION_DISABLE_ERROR,
  CONDITION_SECTION_DISABLE_ERROR,
} from '../constants';
import EditorLayout from '../editor_layout.vue';
import DisabledSection from '../disabled_section.vue';
import RuleSection from './rule/rule_section.vue';
import ScanAction from './action/scan_action.vue';
import {
  buildScannerAction,
  buildDefaultPipeLineRule,
  createPolicyObject,
  DEFAULT_SCAN_EXECUTION_POLICY,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE,
  DEFAULT_SCAN_EXECUTION_POLICY_NEW_FORMAT,
  DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_NEW_FORMAT,
} from './lib';
import {
  DEFAULT_SCANNER,
  ADD_CONDITION_LABEL,
  CONDITIONS_LABEL,
  ERROR_MESSAGE_MAP,
} from './constants';

export default {
  ACTION: 'actions',
  RULE: 'rules',
  EDITOR_MODE_RULE,
  EDITOR_MODE_YAML,
  SECURITY_POLICY_ACTIONS,
  i18n: {
    ACTIONS_LABEL,
    ACTION_SECTION_DISABLE_ERROR,
    ADD_ACTION_LABEL,
    ADD_CONDITION_LABEL,
    CONDITIONS_LABEL,
    CONDITION_SECTION_DISABLE_ERROR,
    PARSING_ERROR_MESSAGE,
    createMergeRequest: __('Configure with a merge request'),
    notOwnerButtonText: __('Learn more'),
    notOwnerDescription: s__(
      'SecurityOrchestration|Scan execution policies can only be created by project owners.',
    ),
    exceedingActionsMessage: s__(
      'SecurityOrchestration|Policy has reached the maximum of %{actionsCount} %{actions}',
    ),
    configurationTitle: s__('SecurityOrchestration|Additional configuration'),
  },
  apollo: {
    projectsCount: {
      query: getGroupProjectsCount,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        return data.group?.projects?.count || 0;
      },
      skip() {
        return !isGroup(this.namespaceType) || !hasScheduledRule(this.policy);
      },
      error() {
        this.projectsCount = 0;
      },
    },
  },
  components: {
    SkipCiSelector,
    DisabledSection,
    GlButton,
    GlEmptyState,
    ScanAction,
    EditorLayout,
    OverloadWarningModal,
    RuleSection,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagMixin()],
  inject: [
    'disableScanPolicyUpdate',
    'policyEditorEmptyStateSvgPath',
    'namespacePath',
    'namespaceType',
    'scanPolicyDocumentationPath',
    'maxScanExecutionPolicyActions',
  ],
  props: {
    assignedPolicyProject: {
      type: Object,
      required: true,
    },
    errorSources: {
      type: Array,
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
    const { securityPoliciesNewYamlFormat } = this.glFeatures;

    const defaultPolicy = securityPoliciesNewYamlFormat
      ? DEFAULT_SCAN_EXECUTION_POLICY_NEW_FORMAT
      : DEFAULT_SCAN_EXECUTION_POLICY;
    const defaultPolicyWithScope = securityPoliciesNewYamlFormat
      ? DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_NEW_FORMAT
      : DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE;

    const newPolicyYaml = isGroup(this.namespaceType) ? defaultPolicyWithScope : defaultPolicy;

    const yamlEditorValue = this.existingPolicy
      ? policyToYaml(this.existingPolicy, POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter)
      : newPolicyYaml;

    const { policy, parsingError } = createPolicyObject(yamlEditorValue);

    const hasSkipCi = 'skip_ci' in policy;
    if (!hasSkipCi && this.glFeatures.securityPoliciesSkipCi) {
      policy.skip_ci = DEFAULT_SKIP_SI_CONFIGURATION;
    }

    return {
      parsingError,
      projectsCount: 0,
      showPerformanceWarningModal: false,
      dismissPerformanceWarningModal: false,
      policy,
      policyModificationAction: null,
      yamlEditorValue,
      mode: EDITOR_MODE_RULE,
      documentationPath: setUrlFragment(
        this.scanPolicyDocumentationPath,
        'scan-execution-policy-editor',
      ),
      specificActionSectionError: '',
    };
  },
  computed: {
    hasSkipCiConfiguration() {
      return this.glFeatures.securityPoliciesSkipCi;
    },
    actionSectionError() {
      return this.specificActionSectionError || this.$options.i18n.ACTION_SECTION_DISABLE_ERROR;
    },
    actions() {
      /**
       * Even though button to add new actions is disabled when limit is reached
       * User can add unlimited number of actions in yaml mode
       * 1000+ actions would hit browser performance and make page slow and unresponsive
       * slicing it to allowed limit would prevent it
       */
      const { actions = [] } = this.policy || {};
      if (this.scanExecutionActionsLimitEnabled) {
        return actions.slice(0, this.maxScanExecutionPolicyActions);
      }

      return actions;
    },
    scanExecutionActionsLimitEnabled() {
      return Boolean(
        this.glFeatures.scanExecutionPolicyActionLimitGroup ||
          this.glFeatures.scanExecutionPolicyActionLimit,
      );
    },
    addActionButtonDisabled() {
      return (
        this.scanExecutionActionsLimitEnabled &&
        this.policy.actions?.length > this.maxScanExecutionPolicyActions
      );
    },
    addActionButtonTitle() {
      const actions = n__('action', 'actions', this.actions?.length);
      return this.addActionButtonDisabled
        ? sprintf(this.$options.i18n.exceedingActionsMessage, {
            actionsCount: this.maxScanExecutionPolicyActions,
            actions,
          })
        : '';
    },
  },
  methods: {
    addAction() {
      if (!this.policy.actions?.length) {
        this.policy = {
          ...this.policy,
          actions: [],
        };
      }

      this.policy.actions.push(buildScannerAction({ scanner: DEFAULT_SCANNER }));
      this.updateYamlEditorValue(this.policy);
    },
    addRule() {
      if (!this.policy.rules?.length) {
        this.policy.rules = [];
      }

      this.policy.rules.push(buildDefaultPipeLineRule());
      this.updateYamlEditorValue(this.policy);
    },
    cancelPolicySubmit() {
      this.policyModificationAction = null;
      this.showPerformanceWarningModal = false;
    },
    confirmPolicySubmit() {
      this.showPerformanceWarningModal = false;
      this.dismissPerformanceWarningModal = true;
      this.handleModifyPolicy(this.policyModificationAction);
    },
    removeActionOrRule(type, index) {
      this.policy[type].splice(index, 1);
      this.updateYamlEditorValue(this.policy);
    },
    updateActionOrRule(type, index, values) {
      this.policy[type].splice(index, 1, values);
      this.updateYamlEditorValue(this.policy);
    },
    changeEditorMode(mode) {
      this.mode = mode;
    },
    handleActionBuilderParsingError(key) {
      this.parsingError = { ...this.parsingError, actions: true };
      this.specificActionSectionError = ERROR_MESSAGE_MAP[key] || '';
    },
    handleRemoveProperty(property) {
      const { [property]: removedProperty, ...updatedPolicy } = this.policy;
      this.policy = updatedPolicy;
      this.updateYamlEditorValue(this.policy);
    },
    handleUpdateProperty(property, value) {
      this.policy[property] = value;
      this.updateYamlEditorValue(this.policy);
    },
    hasPerformanceRisk() {
      return checkForPerformanceRisk({
        namespaceType: this.namespaceType,
        policy: this.policy,
        projectsCount: this.projectsCount,
      });
    },
    async handleModifyPolicy(action) {
      if (this.hasPerformanceRisk() && !this.dismissPerformanceWarningModal) {
        this.policyModificationAction = action;
        this.showPerformanceWarningModal = true;
        return;
      }

      /**
       * backend only accepts the old format
       * policy body is extracted
       * and policy type is added to a policy body
       */
      const type = POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter;
      const policy = extractPolicyContent({ manifest: this.yamlEditorValue, type, withType: true });

      const payload = this.glFeatures.securityPoliciesNewYamlFormat
        ? policyBodyToYaml(policy)
        : this.yamlEditorValue;

      this.$emit('save', { action, policy: payload });
    },
    updateYaml(manifest) {
      const { policy, parsingError } = createPolicyObject(manifest);

      this.yamlEditorValue = manifest;
      this.policy = policy;
      this.parsingError = parsingError;
      this.specificActionSectionError = '';
    },
    updateYamlEditorValue(policy) {
      this.yamlEditorValue = policyToYaml(
        policy,
        POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
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
    @remove-property="handleRemoveProperty"
    @update-property="handleUpdateProperty"
    @update-yaml="updateYaml"
    @update-editor-mode="changeEditorMode"
  >
    <template #rules>
      <disabled-section
        :disabled="parsingError.rules"
        :error="$options.i18n.CONDITION_SECTION_DISABLE_ERROR"
        data-testid="disabled-rule"
      >
        <template #title>
          <h4>{{ $options.i18n.CONDITIONS_LABEL }}</h4>
        </template>

        <rule-section
          v-for="(rule, index) in policy.rules"
          :key="rule.id"
          :data-testid="`rule-${index}`"
          class="gl-mb-4"
          :init-rule="rule"
          :rule-index="index"
          @changed="updateActionOrRule($options.RULE, index, $event)"
          @remove="removeActionOrRule($options.RULE, index)"
        />

        <div class="gl-mb-5 gl-rounded-base gl-bg-subtle gl-p-5">
          <gl-button variant="link" data-testid="add-rule" @click="addRule">
            {{ $options.i18n.ADD_CONDITION_LABEL }}
          </gl-button>
        </div>
      </disabled-section>
    </template>

    <template #actions-first>
      <disabled-section
        :disabled="parsingError.actions"
        :error="actionSectionError"
        data-testid="disabled-action"
      >
        <template #title>
          <h4>{{ $options.i18n.ACTIONS_LABEL }}</h4>
        </template>

        <scan-action
          v-for="(action, index) in actions"
          :key="action.id"
          :data-testid="`action-${index}`"
          class="gl-mb-4"
          :init-action="action"
          :action-index="index"
          :error-sources="errorSources"
          @changed="updateActionOrRule($options.ACTION, index, $event)"
          @remove="removeActionOrRule($options.ACTION, index)"
          @parsing-error="handleActionBuilderParsingError"
        />

        <div class="gl-mb-5 gl-rounded-base gl-bg-subtle gl-p-5">
          <span v-gl-tooltip :title="addActionButtonTitle" data-testid="add-action-wrapper">
            <gl-button
              :disabled="addActionButtonDisabled"
              variant="link"
              data-testid="add-action"
              @click="addAction"
            >
              {{ $options.i18n.ADD_ACTION_LABEL }}
            </gl-button>
          </span>
        </div>
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

    <template #modal>
      <overload-warning-modal
        :visible="showPerformanceWarningModal"
        @cancel-submit="cancelPolicySubmit"
        @confirm-submit="confirmPolicySubmit"
      />
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
