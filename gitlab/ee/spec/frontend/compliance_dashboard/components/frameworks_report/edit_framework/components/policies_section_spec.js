import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlTable, GlBadge, GlButton } from '@gitlab/ui';

import PoliciesSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/policies_section.vue';
import DrawerWrapper from 'ee/security_orchestration/components/policy_drawer/drawer_wrapper.vue';

import complianceFrameworkPoliciesQuery from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/graphql/compliance_frameworks_policies.query.graphql';
import namespacePoliciesQuery from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/graphql/namespace_policies.query.graphql';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';

Vue.use(VueApollo);

const pageInfo = (endCursor) => ({
  hasNextPage: false,
  hasPreviousPage: false,
  startCursor: 'MQ',
  endCursor,
  __typename: 'PageInfo',
});

const editPath = (name) => `http://fake-path/edit/${name}`;
const makePolicy = ({ name, enabled, description, __typename, ...rest }) => ({
  name,
  enabled,
  description,
  yaml: '',
  editPath: editPath(name),
  source: {
    inherited: false,
    namespace: {
      id: '1',
      fullPath: '',
      name,
    },
  },
  updatedAt: Date.now(),
  userApprovers: [],
  allGroupApprovers: [],
  roleApprovers: [],
  __typename,
  ...rest,
});

const makeCompliancePoliciesResponse = () => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/29',
      complianceFrameworks: {
        nodes: [
          {
            id: 'gid://gitlab/ComplianceManagement::Framework/7',
            name: 'ddd',
            scanResultPolicies: {
              nodes: [{ name: 'test', __typename: 'ScanResultPolicy' }],
              pageInfo: pageInfo('A2'),
              __typename: 'ScanResultPolicyConnection',
            },
            scanExecutionPolicies: {
              nodes: [{ name: 'testE2', __typename: 'ScanExecutionPolicy' }],
              pageInfo: pageInfo('SE2'),
              __typename: 'ScanExecutionPolicyConnection',
            },
            pipelineExecutionPolicies: {
              nodes: [{ name: 'testPE', __typename: 'PipelineExecutionPolicy' }],
              pageInfo: pageInfo('PE2'),
              __typename: 'PipelineExecutionPolicyConnection',
            },
            vulnerabilityManagementPolicies: {
              nodes: [{ name: 'testVM', __typename: 'VulnerabilityManagementPolicy' }],
              pageInfo: pageInfo('VM2'),
              __typename: 'VulnerabilityManagementPolicyConnection',
            },
            __typename: 'ComplianceFramework',
          },
        ],
        __typename: 'ComplianceFrameworkConnection',
      },
      __typename: 'Namespace',
    },
  },
});

const makeNamespacePoliciesResponse = () => ({
  data: {
    namespace: {
      id: 'gid://gitlab/Group/29',
      approvalPolicies: {
        nodes: [
          makePolicy({
            name: 'test',
            enabled: false,
            description: 'Test1',
            __typename: 'ApprovalPolicy',
          }),
          makePolicy({
            name: 'test2',
            enabled: true,
            description: 'Test2',
            __typename: 'ApprovalPolicy',
          }),
        ],
        pageInfo: pageInfo('A1'),
        __typename: 'ApprovalPolicyConnection',
      },
      scanExecutionPolicies: {
        nodes: [
          makePolicy({
            name: 'testE',
            enabled: false,
            description: 'E1',
            __typename: 'ScanExecutionPolicy',
          }),
          makePolicy({
            name: 'testE2',
            enabled: true,
            description: 'E2',
            __typename: 'ScanExecutionPolicy',
          }),
        ],
        pageInfo: pageInfo('SE1'),
        __typename: 'ScanExecutionPolicyConnection',
      },
      pipelineExecutionPolicies: {
        nodes: [
          makePolicy({
            name: 'testPE',
            enabled: true,
            description: 'PE1',
            __typename: 'PipelineExecutionPolicy',
          }),
          makePolicy({
            name: 'testPE2',
            enabled: false,
            description: 'PE2',
            __typename: 'PipelineExecutionPolicy',
          }),
        ],
        pageInfo: pageInfo('PE1'),
        __typename: 'PipelineExecutionPolicyConnection',
      },
      vulnerabilityManagementPolicies: {
        nodes: [
          makePolicy({
            name: 'testVM',
            enabled: true,
            description: 'VM1',
            __typename: 'VulnerabilityManagementPolicy',
          }),
          makePolicy({
            name: 'testVM2',
            enabled: false,
            description: 'VM2',
            __typename: 'VulnerabilityManagementPolicy',
          }),
        ],
        pageInfo: pageInfo('VM1'),
        __typename: 'VulnerabilityManagementPolicyConnection',
      },
      __typename: 'Namespace',
    },
  },
});

describe('PoliciesSection component', () => {
  let wrapper;
  const findPoliciesTable = () => wrapper.findComponent(GlTable);
  const findDrawer = () => wrapper.findComponent(DrawerWrapper);

  function createComponent({ requestHandlers = [], provide } = {}) {
    return mountExtended(PoliciesSection, {
      apolloProvider: createMockApollo(requestHandlers),
      provide: {
        disableScanPolicyUpdate: false,
        groupSecurityPoliciesPath: '/group-security-policies',
        ...provide,
      },
      stubs: {
        DrawerWrapper: true,
      },
      propsData: {
        fullPath: 'Commit451',
        graphqlId: 'gid://gitlab/ComplianceManagement::Framework/1',
      },
    });
  }

  describe('when multiple pages are present', () => {
    let namespaceLoadHandler;
    let complianceLoadHandler;

    beforeEach(() => {
      const responseWithNextPages = makeNamespacePoliciesResponse();
      responseWithNextPages.data.namespace.approvalPolicies.pageInfo.hasNextPage = true;

      namespaceLoadHandler = jest
        .fn()
        .mockResolvedValueOnce(responseWithNextPages)
        .mockResolvedValueOnce(makeNamespacePoliciesResponse());

      complianceLoadHandler = jest
        .fn()
        .mockResolvedValueOnce(makeCompliancePoliciesResponse())
        .mockResolvedValueOnce(makeCompliancePoliciesResponse());

      wrapper = createComponent({
        requestHandlers: [
          [namespacePoliciesQuery, namespaceLoadHandler],
          [complianceFrameworkPoliciesQuery, complianceLoadHandler],
        ],
      });
    });

    it('loads next pages for namespace policies with appropriate cursors if has next pages', async () => {
      await waitForPromises();

      expect(namespaceLoadHandler).toHaveBeenCalledWith({
        approvalPoliciesAfter: 'A1',
        scanExecutionPoliciesAfter: 'SE1',
        pipelineExecutionPoliciesAfter: 'PE1',
        vulnerabilityManagementPoliciesAfter: 'VM1',
        fullPath: 'Commit451',
      });

      expect(complianceLoadHandler).toHaveBeenCalledWith({
        complianceFramework: 'gid://gitlab/ComplianceManagement::Framework/1',
        fullPath: 'Commit451',
        approvalPoliciesAfter: null,
        pipelineExecutionPoliciesAfter: null,
        scanExecutionPoliciesAfter: null,
        vulnerabilityManagementPoliciesAfter: null,
      });
    });

    it('correctly stops loading next pages for namespace policies after two calls', async () => {
      await waitForPromises();
      await waitForPromises();
      expect(namespaceLoadHandler).toHaveBeenCalledTimes(2);
    });

    it('correctly loads compliance policies', async () => {
      await waitForPromises();

      expect(complianceLoadHandler).toHaveBeenCalledTimes(1);
      expect(complianceLoadHandler).toHaveBeenCalledWith({
        complianceFramework: 'gid://gitlab/ComplianceManagement::Framework/1',
        fullPath: 'Commit451',
        approvalPoliciesAfter: null,
        pipelineExecutionPoliciesAfter: null,
        scanExecutionPoliciesAfter: null,
        vulnerabilityManagementPoliciesAfter: null,
      });
    });
  });

  describe('when loaded', () => {
    beforeEach(() => {
      wrapper = createComponent({
        requestHandlers: [
          [namespacePoliciesQuery, jest.fn().mockResolvedValue(makeNamespacePoliciesResponse())],
          [
            complianceFrameworkPoliciesQuery,
            jest.fn().mockResolvedValue(makeCompliancePoliciesResponse()),
          ],
        ],
      });

      return waitForPromises();
    });

    it('renders title', () => {
      const title = wrapper.findByText('Policies');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        'Select policies to enforce on all projects scoped to this framework.',
      );
      expect(description.exists()).toBe(true);
    });

    it('renders info text with link', () => {
      expect(wrapper.findByTestId('info-text').text()).toContain(
        'Go to the policy management page to scope policies for this framework.',
      );
      expect(wrapper.findByTestId('info-text').find('a').attributes('href')).toBe(
        '/group-security-policies',
      );
    });

    it('correctly calculates policies', () => {
      const { items: policies } = findPoliciesTable().vm.$attrs;
      expect(policies).toHaveLength(4);
      expect(policies.find((p) => p.name === 'test')).toBeDefined();
      expect(policies.find((p) => p.name === 'testE2')).toBeDefined();
      expect(policies.find((p) => p.name === 'testPE')).toBeDefined();
      expect(policies.find((p) => p.name === 'testVM')).toBeDefined();
    });

    it('displays disabled badge for disabled policy', () => {
      const disabledBadges = wrapper
        .findAllComponents(GlBadge)
        .wrappers.filter((badge) => badge.text() === 'Disabled');
      expect(disabledBadges).toHaveLength(1);
      const disabledPolicyNames = disabledBadges.map((badgeWrapper) =>
        badgeWrapper.element.closest('tr').querySelector('td span').textContent.trim(),
      );
      expect(disabledPolicyNames).toEqual(['test']);
    });

    it('renders buttons to view policy details', async () => {
      const { items: policies } = findPoliciesTable().vm.$attrs;
      const policyButtons = findPoliciesTable().findAllComponents(GlButton);
      expect(policyButtons).toHaveLength(policies.length);
      policyButtons.at(0).vm.$emit('click');
      await nextTick();
      expect(findDrawer().props('policy')).toEqual(policies[0]);
    });

    describe('Drawer', () => {
      it('renders with selected policy', async () => {
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();
        expect(findDrawer().props('policyType')).toBe('approval');
        expect(findDrawer().props('policy').name).toBe('test');
      });

      it('deselects policy when drawer emits close event', async () => {
        await wrapper.find('table tbody tr').trigger('click');
        await nextTick();
        expect(findDrawer().props('policy').name).toBe('test');
        findDrawer().vm.$emit('close');
        await nextTick();
        expect(findDrawer().props('policy')).toBeNull();
      });
    });
  });
});
