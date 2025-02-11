<script>
import { s__ } from '~/locale';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createAlert } from '~/alert';
import { getParameterByName } from '~/lib/utils/url_utility';
import {
  exceedsActionLimit,
  extractSourceParameter,
  extractTypeParameter,
} from 'ee/security_orchestration/components/policies/utils';
import { isGroup } from '../utils';
import projectScanExecutionPoliciesQuery from '../../graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from '../../graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from '../../graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from '../../graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from '../../graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from '../../graphql/queries/group_pipeline_execution_policies.query.graphql';
import projectVulnerabilityManagementPoliciesQuery from '../../graphql/queries/project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPoliciesQuery from '../../graphql/queries/group_vulnerability_management_policies.query.graphql';
import ListHeader from './list_header.vue';
import ListComponent from './list_component.vue';
import { DEPRECATED_CUSTOM_SCAN_PROPERTY, POLICY_TYPE_FILTER_OPTIONS } from './constants';

const NAMESPACE_QUERY_DICT = {
  scanExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectScanExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanExecutionPoliciesQuery,
  },
  scanResult: {
    [NAMESPACE_TYPES.PROJECT]: projectScanResultPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupScanResultPoliciesQuery,
  },
  pipelineExecution: {
    [NAMESPACE_TYPES.PROJECT]: projectPipelineExecutionPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupPipelineExecutionPoliciesQuery,
  },
  vulnerabilityManagement: {
    [NAMESPACE_TYPES.PROJECT]: projectVulnerabilityManagementPoliciesQuery,
    [NAMESPACE_TYPES.GROUP]: groupVulnerabilityManagementPoliciesQuery,
  },
};

const createPolicyFetchError = ({ gqlError, networkError }) => {
  const error =
    gqlError?.message ||
    networkError?.message ||
    s__('SecurityOrchestration|Something went wrong, unable to fetch policies');
  createAlert({
    message: error,
  });
};

export default {
  components: {
    ListHeader,
    ListComponent,
  },
  inject: [
    'assignedPolicyProject',
    'namespacePath',
    'namespaceType',
    'maxScanExecutionPolicyActions',
  ],
  apollo: {
    linkedSppItems: {
      query: getSppLinkedProjectsGroups,
      variables() {
        return {
          fullPath: this.namespacePath,
        };
      },
      update(data) {
        const {
          securityPolicyProjectLinkedProjects: { nodes: linkedProjects = [] } = {},
          securityPolicyProjectLinkedGroups: { nodes: linkedGroups = [] } = {},
        } = data?.project || {};

        return [...linkedProjects, ...linkedGroups];
      },
      skip() {
        return isGroup(this.namespaceType);
      },
      error: createPolicyFetchError,
    },
    scanExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanExecution[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.scanExecutionPolicies?.nodes ?? [];
      },
      result({ data }) {
        const policies = data?.namespace?.scanExecutionPolicies?.nodes ?? [];
        this.hasDeprecatedCustomScanPolicies = policies.some((policy) =>
          policy.deprecatedProperties.includes(DEPRECATED_CUSTOM_SCAN_PROPERTY),
        );

        this.hasExceedingActionLimitPolicies = policies.some(({ yaml }) =>
          exceedsActionLimit({
            policyType: POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.text,
            yaml,
            maxScanExecutionPolicyActions: this.maxScanExecutionPolicyActions,
          }),
        );
      },
      error: createPolicyFetchError,
    },
    scanResultPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.scanResult[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.scanResultPolicies?.nodes ?? [];
      },
      result({ data }) {
        const policies = data?.namespace?.scanResultPolicies?.nodes ?? [];
        this.hasInvalidPolicies = policies.some((policy) =>
          policy.deprecatedProperties.some((prop) => prop !== 'scan_result_policy'),
        );
      },
      error: createPolicyFetchError,
    },
    pipelineExecutionPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.pipelineExecution[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.pipelineExecutionPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
    },
    vulnerabilityManagementPolicies: {
      query() {
        return NAMESPACE_QUERY_DICT.vulnerabilityManagement[this.namespaceType];
      },
      variables() {
        return {
          fullPath: this.namespacePath,
          relationship: this.selectedPolicySource,
        };
      },
      update(data) {
        return data?.namespace?.vulnerabilityManagementPolicies?.nodes ?? [];
      },
      error: createPolicyFetchError,
    },
  },
  data() {
    const selectedPolicySource = extractSourceParameter(getParameterByName('source'));
    const selectedPolicyType = extractTypeParameter(getParameterByName('type'));

    return {
      hasExceedingActionLimitPolicies: false,
      hasInvalidPolicies: false,
      hasDeprecatedCustomScanPolicies: false,
      hasPolicyProject: Boolean(this.assignedPolicyProject?.id),
      selectedPolicySource,
      selectedPolicyType,
      shouldUpdatePolicyList: false,
      linkedSppItems: [],
      pipelineExecutionPolicies: [],
      scanExecutionPolicies: [],
      scanResultPolicies: [],
      vulnerabilityManagementPolicies: [],
    };
  },
  computed: {
    policiesByType() {
      return {
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: this.scanExecutionPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: this.scanResultPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]: this.pipelineExecutionPolicies,
        [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
          this.vulnerabilityManagementPolicies,
      };
    },
    isLoadingPolicies() {
      return (
        this.$apollo.queries.scanExecutionPolicies.loading ||
        this.$apollo.queries.scanResultPolicies.loading ||
        this.$apollo.queries.pipelineExecutionPolicies.loading ||
        this.$apollo.queries.vulnerabilityManagementPolicies.loading
      );
    },
  },
  methods: {
    handleClearedSelected() {
      this.shouldUpdatePolicyList = false;
    },
    handleUpdatePolicyList({ hasPolicyProject, shouldUpdatePolicyList = false }) {
      if (hasPolicyProject !== undefined) {
        this.hasPolicyProject = hasPolicyProject;
      }

      this.shouldUpdatePolicyList = shouldUpdatePolicyList;

      this.$apollo.queries.scanExecutionPolicies.refetch();
      this.$apollo.queries.scanResultPolicies.refetch();
    },
    handleUpdatePolicySource(value) {
      this.selectedPolicySource = value;
    },
    handleUpdatePolicyType(value) {
      this.selectedPolicyType = value;
    },
  },
};
</script>
<template>
  <div>
    <list-header
      :has-exceeding-action-limit-policies="hasExceedingActionLimitPolicies"
      :has-invalid-policies="hasInvalidPolicies"
      :has-deprecated-custom-scan-policies="hasDeprecatedCustomScanPolicies"
      @update-policy-list="handleUpdatePolicyList"
    />
    <list-component
      :has-policy-project="hasPolicyProject"
      :should-update-policy-list="shouldUpdatePolicyList"
      :is-loading-policies="isLoadingPolicies"
      :selected-policy-source="selectedPolicySource"
      :selected-policy-type="selectedPolicyType"
      :linked-spp-items="linkedSppItems"
      :policies-by-type="policiesByType"
      @cleared-selected="handleClearedSelected"
      @update-policy-source="handleUpdatePolicySource"
      @update-policy-type="handleUpdatePolicyType"
    />
  </div>
</template>
