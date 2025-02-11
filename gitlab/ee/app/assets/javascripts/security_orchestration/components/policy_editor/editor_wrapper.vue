<script>
import { GlAlert, GlFormGroup, GlFormSelect } from '@gitlab/ui';
import getSecurityPolicyProjectSub from 'ee/security_orchestration/graphql/queries/security_policy_project_created.subscription.graphql';
import { NAMESPACE_TYPES } from '../../constants';
import { POLICY_TYPE_COMPONENT_OPTIONS } from '../constants';
import { fromYaml } from '../utils';
import { GRAPHQL_ERROR_MESSAGE, SECURITY_POLICY_ACTIONS } from './constants';
import { assignSecurityPolicyProjectAsync, goToPolicyMR, parseError } from './utils';
import PipelineExecutionPolicyEditor from './pipeline_execution/editor_component.vue';
import ScanExecutionPolicyEditor from './scan_execution/editor_component.vue';
import ScanResultPolicyEditor from './scan_result/editor_component.vue';
import VulnerabilityManagementPolicyEditor from './vulnerability_management/editor_component.vue';

export default {
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      newlyCreatedPolicyProject: {
        query() {
          return getSecurityPolicyProjectSub;
        },
        variables() {
          return { fullPath: this.namespacePath };
        },
        result({ data: { securityPolicyProjectCreated } }) {
          if (!securityPolicyProjectCreated) return;

          const { project, errors } = securityPolicyProjectCreated;

          if (errors.length) {
            this.setError(errors.join('\n'));
            this.setLoadingFlag(false);
          }

          if (project) {
            this.currentAssignedPolicyProject = {
              ...project,
              branch: project?.branch?.rootRef,
            };
          }
        },
        error(e) {
          this.setError(e.message);
          this.setLoadingFlag(false);
        },
      },
    },
  },
  components: {
    GlAlert,
    GlFormGroup,
    GlFormSelect,
    PipelineExecutionPolicyEditor,
    ScanExecutionPolicyEditor,
    ScanResultPolicyEditor,
    VulnerabilityManagementPolicyEditor,
  },
  inject: {
    assignedPolicyProject: { default: null },
    existingPolicy: { default: null },
    namespaceType: { default: NAMESPACE_TYPES.PROJECT },
    namespacePath: { default: '' },
  },
  props: {
    // This is the `value` field of the POLICY_TYPE_COMPONENT_OPTIONS
    selectedPolicyType: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      currentAssignedPolicyProject: this.assignedPolicyProject,
      isRuleMode: true,
      error: '',
      errorMessages: [],
      errorSources: [],
      extraMergeRequestInput: null,
      isCreating: false,
      isDeleting: false,
      policy: null,
      policyModificationAction: null,
    };
  },
  computed: {
    isEditing() {
      return Boolean(this.existingPolicy);
    },
    policyActionName() {
      return this.isEditing ? SECURITY_POLICY_ACTIONS.REPLACE : SECURITY_POLICY_ACTIONS.APPEND;
    },
    originalName() {
      return this.existingPolicy?.name;
    },
    policyTypes() {
      return Object.values(POLICY_TYPE_COMPONENT_OPTIONS);
    },
    policyOptions() {
      return (
        this.policyTypes.find(({ value }) => value === this.selectedPolicyType) ||
        POLICY_TYPE_COMPONENT_OPTIONS.scanExecution
      );
    },
    shouldAllowPolicyTypeSelection() {
      return !this.existingPolicy;
    },
  },
  watch: {
    async currentAssignedPolicyProject(project) {
      await this.createPolicyModification(project);
    },
  },
  methods: {
    handleError(error) {
      // Refactor errorSources to allow for customization as part of
      // https://gitlab.com/gitlab-org/gitlab/-/issues/486021
      const newErrorSources = [];
      // Emit error for alert
      if (this.isRuleMode && error.cause?.length) {
        const ACTION_ERROR_FIELD = 'actions';

        const actionErrors = error.cause.filter((cause) => ACTION_ERROR_FIELD === cause.field);

        if (error.cause.length > actionErrors.length) {
          this.setError(error.message);
        }

        // Errors due to the approvers ids do not show up at the top level, so we do not
        // call setError
        if (actionErrors.length) {
          newErrorSources.push(['action', '0', ACTION_ERROR_FIELD, actionErrors]);
        }
      } else if (error.message.toLowerCase().includes('graphql')) {
        this.setError(GRAPHQL_ERROR_MESSAGE);
      } else {
        this.setError(error.message);
      }

      // Process error to pass to specific component
      this.errorSources = [...newErrorSources, ...parseError(error)];
    },
    async handleSave({ action, extraMergeRequestInput = null, policy, isRuleMode = false }) {
      this.extraMergeRequestInput = extraMergeRequestInput;
      this.policyModificationAction = action || this.policyActionName;
      this.policy = policy;
      this.isRuleMode = isRuleMode;

      this.setError('');
      this.setLoadingFlag(true);

      try {
        if (!this.assignedPolicyProject.fullPath) {
          await assignSecurityPolicyProjectAsync(this.namespacePath);
        } else {
          await this.createPolicyModification(this.assignedPolicyProject);
        }
      } catch (e) {
        this.handleError(e);
        this.setLoadingFlag(false);
      }
    },
    async createPolicyModification(assignedPolicyProject) {
      if (!this.policy || !this.policyModificationAction) return;

      this.setError('');
      this.setLoadingFlag(true);

      try {
        await goToPolicyMR({
          action: this.policyModificationAction,
          assignedPolicyProject,
          extraMergeRequestInput: this.extraMergeRequestInput,
          name: this.originalName || fromYaml({ manifest: this.policy })?.name,
          namespacePath: this.namespacePath,
          yamlEditorValue: this.policy,
        });
      } catch (e) {
        this.handleError(e);
        this.setLoadingFlag(false);
        this.policyModificationAction = null;
      }
    },
    setError(errors) {
      [this.error, ...this.errorMessages] = errors.split('\n');
    },
    setLoadingFlag(val) {
      if (this.policyModificationAction === SECURITY_POLICY_ACTIONS.REMOVE) {
        this.isDeleting = val;
      } else {
        this.isCreating = val;
      }
    },
  },
  NAMESPACE_TYPES,
};
</script>

<template>
  <section class="policy-editor">
    <gl-alert
      v-if="error"
      class="security-policies-alert gl-z-2 gl-mt-5"
      :title="error"
      dismissible
      variant="danger"
      data-testid="error-alert"
      sticky
      @dismiss="setError('')"
    >
      <ul v-if="errorMessages.length" class="!gl-mb-0 gl-ml-5">
        <li v-for="errorMessage in errorMessages" :key="errorMessage">
          {{ errorMessage }}
        </li>
      </ul>
    </gl-alert>
    <component
      :is="policyOptions.component"
      :error-sources="errorSources"
      :existing-policy="existingPolicy"
      :assigned-policy-project="currentAssignedPolicyProject"
      :is-creating="isCreating"
      :is-deleting="isDeleting"
      :is-editing="isEditing"
      @save="handleSave"
      @error="setError($event)"
    />
  </section>
</template>
