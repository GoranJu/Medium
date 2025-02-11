import { nextTick } from 'vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { createAlert } from '~/alert';
import ListHeader from 'ee/security_orchestration/components/policies/list_header.vue';
import ListComponent from 'ee/security_orchestration/components/policies/list_component.vue';
import App from 'ee/security_orchestration/components/policies/app.vue';
import {
  MAX_SCAN_EXECUTION_ACTION_COUNT,
  NAMESPACE_TYPES,
} from 'ee/security_orchestration/constants';
import {
  DEPRECATED_CUSTOM_SCAN_PROPERTY,
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import getSppLinkedProjectsGroups from 'ee/security_orchestration/graphql/queries/get_spp_linked_projects_groups.graphql';
import projectScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_execution_policies.query.graphql';
import groupScanExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_execution_policies.query.graphql';
import projectScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_scan_result_policies.query.graphql';
import groupScanResultPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_scan_result_policies.query.graphql';
import projectPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_pipeline_execution_policies.query.graphql';
import groupPipelineExecutionPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_pipeline_execution_policies.query.graphql';
import projectVulnerabilityManagementPoliciesQuery from 'ee/security_orchestration/graphql/queries/project_vulnerability_management_policies.query.graphql';
import groupVulnerabilityManagementPoliciesQuery from 'ee/security_orchestration/graphql/queries/group_vulnerability_management_policies.query.graphql';
import { mockPipelineExecutionPoliciesResponse } from '../../mocks/mock_pipeline_execution_policy_data';
import { mockVulnerabilityManagementPoliciesResponse } from '../../mocks/mock_vulnerability_management_policy_data';
import {
  projectScanExecutionPolicies,
  groupScanExecutionPolicies,
  projectScanResultPolicies,
  groupScanResultPolicies,
  projectPipelineResultPolicies,
  groupPipelineResultPolicies,
  projectVulnerabilityManagementPolicies,
  groupVulnerabilityManagementPolicies,
  mockLinkedSppItemsResponse,
} from '../../mocks/mock_apollo';
import {
  mockProjectScanExecutionPolicy,
  mockScanExecutionPoliciesResponse,
} from '../../mocks/mock_scan_execution_policy_data';
import {
  mockScanResultPoliciesResponse,
  mockProjectScanResultPolicy,
} from '../../mocks/mock_scan_result_policy_data';

jest.mock('~/alert');

const projectScanExecutionPoliciesSpy = projectScanExecutionPolicies(
  mockScanExecutionPoliciesResponse,
);
const groupScanExecutionPoliciesSpy = groupScanExecutionPolicies(mockScanExecutionPoliciesResponse);
const projectScanResultPoliciesSpy = projectScanResultPolicies(mockScanResultPoliciesResponse);
const groupScanResultPoliciesSpy = groupScanResultPolicies(mockScanResultPoliciesResponse);
const projectPipelineExecutionPoliciesSpy = projectPipelineResultPolicies(
  mockPipelineExecutionPoliciesResponse,
);
const groupPipelineExecutionPoliciesSpy = groupPipelineResultPolicies(
  mockPipelineExecutionPoliciesResponse,
);
const projectVulnerabilityManagementPoliciesSpy = projectVulnerabilityManagementPolicies(
  mockVulnerabilityManagementPoliciesResponse,
);
const groupVulnerabilityManagementPoliciesSpy = groupVulnerabilityManagementPolicies(
  mockVulnerabilityManagementPoliciesResponse,
);

const linkedSppItemsResponseSpy = mockLinkedSppItemsResponse();
const defaultRequestHandlers = {
  projectScanExecutionPolicies: projectScanExecutionPoliciesSpy,
  groupScanExecutionPolicies: groupScanExecutionPoliciesSpy,
  projectScanResultPolicies: projectScanResultPoliciesSpy,
  groupScanResultPolicies: groupScanResultPoliciesSpy,
  projectPipelineExecutionPolicies: projectPipelineExecutionPoliciesSpy,
  groupPipelineExecutionPolicies: groupPipelineExecutionPoliciesSpy,
  projectVulnerabilityManagementPolicies: projectVulnerabilityManagementPoliciesSpy,
  groupVulnerabilityManagementPolicies: groupVulnerabilityManagementPoliciesSpy,
  linkedSppItemsResponse: linkedSppItemsResponseSpy,
};

describe('App', () => {
  let wrapper;
  let requestHandlers;
  const namespacePath = 'path/to/project/or/group';

  const createWrapper = ({ assignedPolicyProject = null, handlers = {}, provide = {} } = {}) => {
    requestHandlers = {
      ...defaultRequestHandlers,
      ...handlers,
    };

    wrapper = shallowMountExtended(App, {
      provide: {
        assignedPolicyProject,
        namespacePath,
        namespaceType: NAMESPACE_TYPES.PROJECT,
        maxScanExecutionPolicyActions: MAX_SCAN_EXECUTION_ACTION_COUNT,
        ...provide,
      },
      apolloProvider: createMockApollo([
        [projectScanExecutionPoliciesQuery, requestHandlers.projectScanExecutionPolicies],
        [groupScanExecutionPoliciesQuery, requestHandlers.groupScanExecutionPolicies],
        [projectScanResultPoliciesQuery, requestHandlers.projectScanResultPolicies],
        [groupScanResultPoliciesQuery, requestHandlers.groupScanResultPolicies],
        [getSppLinkedProjectsGroups, requestHandlers.linkedSppItemsResponse],
        [projectPipelineExecutionPoliciesQuery, requestHandlers.projectPipelineExecutionPolicies],
        [groupPipelineExecutionPoliciesQuery, requestHandlers.groupPipelineExecutionPolicies],
        [
          projectVulnerabilityManagementPoliciesQuery,
          requestHandlers.projectVulnerabilityManagementPolicies,
        ],
        [
          groupVulnerabilityManagementPoliciesQuery,
          requestHandlers.groupVulnerabilityManagementPolicies,
        ],
      ]),
    });
  };

  const findPoliciesHeader = () => wrapper.findComponent(ListHeader);
  const findPoliciesList = () => wrapper.findComponent(ListComponent);

  beforeEach(() => {
    gon.features = {};
  });

  describe('loading', () => {
    it('renders the policies list correctly', () => {
      createWrapper();
      expect(findPoliciesList().props('isLoadingPolicies')).toBe(true);
    });
  });

  describe('default', () => {
    beforeEach(async () => {
      createWrapper();
      await waitForPromises();
    });

    it('renders the policies list correctly', () => {
      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          shouldUpdatePolicyList: false,
          hasPolicyProject: false,
          selectedPolicySource: POLICY_SOURCE_OPTIONS.ALL.value,
          selectedPolicyType: POLICY_TYPE_FILTER_OPTIONS.ALL.value,
        }),
      );
      expect(findPoliciesList().props('policiesByType')).toEqual({
        [POLICY_TYPE_FILTER_OPTIONS.SCAN_EXECUTION.value]: mockScanExecutionPoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.APPROVAL.value]: mockScanResultPoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.PIPELINE_EXECUTION.value]:
          mockPipelineExecutionPoliciesResponse,
        [POLICY_TYPE_FILTER_OPTIONS.VULNERABILITY_MANAGEMENT.value]:
          mockVulnerabilityManagementPoliciesResponse,
      });
    });

    it('renders the policy header correctly', () => {
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toBe(false);
    });

    it('fetches linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(1);
    });

    it('updates the policy list when a the security policy project is changed', async () => {
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(1);
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(false);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(false);
      findPoliciesHeader().vm.$emit('update-policy-list', {
        shouldUpdatePolicyList: true,
        hasPolicyProject: true,
      });
      await nextTick();
      expect(findPoliciesList().props('shouldUpdatePolicyList')).toBe(true);
      expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
      expect(projectScanExecutionPoliciesSpy).toHaveBeenCalledTimes(2);
    });

    it.each`
      type                          | groupHandler                              | projectHandler
      ${'scan execution'}           | ${'groupScanExecutionPolicies'}           | ${'projectScanExecutionPolicies'}
      ${'scan result'}              | ${'groupScanResultPolicies'}              | ${'projectScanResultPolicies'}
      ${'pipeline execution'}       | ${'groupPipelineExecutionPolicies'}       | ${'projectPipelineExecutionPolicies'}
      ${'vulnerability management'} | ${'groupVulnerabilityManagementPolicies'} | ${'projectVulnerabilityManagementPolicies'}
    `(
      'fetches project-level $type policies instead of group-level',
      ({ groupHandler, projectHandler }) => {
        expect(requestHandlers[groupHandler]).not.toHaveBeenCalled();
        expect(requestHandlers[projectHandler]).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        });
      },
    );
  });

  it('renders correctly when a policy project is linked', async () => {
    createWrapper({ assignedPolicyProject: { id: '1' } });
    await nextTick();

    expect(findPoliciesList().props('hasPolicyProject')).toBe(true);
  });

  describe('network errors', () => {
    beforeEach(async () => {
      const errorHandlers = Object.keys(defaultRequestHandlers).reduce((acc, curr) => {
        acc[curr] = jest.fn().mockRejectedValue();
        return acc;
      }, {});
      createWrapper({ handlers: errorHandlers });
      await waitForPromises();
    });

    it('shows an alert', () => {
      expect(createAlert).toHaveBeenCalledTimes(5);
      expect(createAlert).toHaveBeenCalledWith({
        message: 'Something went wrong, unable to fetch policies',
      });
    });

    it('uses an empty array as the default value', () => {
      expect(findPoliciesList().props()).toEqual(
        expect.objectContaining({
          linkedSppItems: [],
          policiesByType: {
            APPROVAL: [],
            PIPELINE_EXECUTION: [],
            SCAN_EXECUTION: [],
            VULNERABILITY_MANAGEMENT: [],
          },
        }),
      );
    });
  });

  describe('group-level policies', () => {
    beforeEach(async () => {
      createWrapper({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
      await waitForPromises();
    });

    it('does not fetch linked SPP items', () => {
      expect(linkedSppItemsResponseSpy).toHaveBeenCalledTimes(0);
    });

    it.each`
      type                          | groupHandler                              | projectHandler
      ${'scan execution'}           | ${'groupScanExecutionPolicies'}           | ${'projectScanExecutionPolicies'}
      ${'scan result'}              | ${'groupScanResultPolicies'}              | ${'projectScanResultPolicies'}
      ${'pipeline execution'}       | ${'groupPipelineExecutionPolicies'}       | ${'projectPipelineExecutionPolicies'}
      ${'vulnerability management'} | ${'groupVulnerabilityManagementPolicies'} | ${'projectVulnerabilityManagementPolicies'}
    `(
      'fetches group-level $type policies instead of project-level',
      ({ groupHandler, projectHandler }) => {
        expect(requestHandlers[projectHandler]).not.toHaveBeenCalled();
        expect(requestHandlers[groupHandler]).toHaveBeenCalledWith({
          fullPath: namespacePath,
          relationship: POLICY_SOURCE_OPTIONS.ALL.value,
        });
      },
    );
  });

  describe('invalid policies', () => {
    it('updates "hasInvalidPolicies" when there are deprecated properties in scan result policies that are not "type: scan_result_policy"', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['test', 'test1'] },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are deprecated properties in scan result policies that are "type: scan_result_policy"', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: ['scan_result_policy'] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });

    it('does not emit that a policy is invalid when there are no deprecated properties', async () => {
      createWrapper({
        handlers: {
          projectScanResultPolicies: projectScanResultPolicies([
            { ...mockProjectScanResultPolicy, deprecatedProperties: [] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasInvalidPolicies')).toEqual(false);
    });
  });

  describe('deprecated custom scan action policies', () => {
    it('updates "hasDeprecatedCustomScanPolicies" when there are deprecated properties in scan execution policies', async () => {
      createWrapper({
        handlers: {
          projectScanExecutionPolicies: projectScanExecutionPolicies([
            {
              ...mockProjectScanExecutionPolicy,
              deprecatedProperties: [DEPRECATED_CUSTOM_SCAN_PROPERTY],
            },
          ]),
        },
      });
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(false);
      await waitForPromises();
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(true);
    });

    it('does not emit that a policy is invalid when there are no deprecated properties', async () => {
      createWrapper({
        handlers: {
          projectScanExecutionPolicies: projectScanExecutionPolicies([
            { ...mockProjectScanExecutionPolicy, deprecatedProperties: [] },
          ]),
        },
      });
      await waitForPromises();
      expect(findPoliciesHeader().props('hasDeprecatedCustomScanPolicies')).toEqual(false);
    });
  });
});
