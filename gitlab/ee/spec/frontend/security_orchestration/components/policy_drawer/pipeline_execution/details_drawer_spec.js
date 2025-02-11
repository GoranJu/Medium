import { GlLink } from '@gitlab/ui';
import PipelineExecutionDrawer from 'ee/security_orchestration/components/policy_drawer/pipeline_execution/details_drawer.vue';
import PolicyDrawerLayout from 'ee/security_orchestration/components/policy_drawer/drawer_layout.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trimText } from 'helpers/text_helper';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import {
  mockProjectPipelineExecutionPolicy,
  mockProjectPipelineExecutionWithConfigurationPolicy,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';

describe('PipelineExecutionDrawer', () => {
  let wrapper;

  const findSummary = () => wrapper.findByTestId('policy-summary');
  const findSummaryHeader = () => wrapper.findByTestId('summary-header');
  const findSummaryFields = () => wrapper.findAllByTestId('summary-fields');
  const findProjectSummary = () => wrapper.findByTestId('project');
  const findFileSummary = () => wrapper.findByTestId('file');
  const findPolicyDrawerLayout = () => wrapper.findComponent(PolicyDrawerLayout);
  const findLink = (parent) => parent.findComponent(GlLink);
  const findConfigurationRow = () => wrapper.findByTestId('policy-configuration');

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    wrapper = shallowMountExtended(PipelineExecutionDrawer, {
      propsData,
      provide: { namespaceType: NAMESPACE_TYPES.PROJECT, ...provide },
      stubs: {
        PolicyDrawerLayout,
      },
    });
  };

  describe('policy drawer layout props', () => {
    it('passes the policy to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('policy')).toEqual(mockProjectPipelineExecutionPolicy);
    });

    it('passes the description to the PolicyDrawerLayout component', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });
      expect(findPolicyDrawerLayout().props('description')).toBe(
        'This policy enforces pipeline execution with configuration from external file',
      );
    });

    it('renders layout if yaml is invalid', () => {
      createComponent({ propsData: { policy: {} } });

      expect(findPolicyDrawerLayout().exists()).toBe(true);
      expect(findPolicyDrawerLayout().props('description')).toBe('');
    });
  });

  describe('summary', () => {
    it('renders paragraph policy summary as text', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      expect(findSummary().exists()).toBe(true);
      expect(findConfigurationRow().exists()).toBe(false);
      expect(findSummaryFields()).toHaveLength(1);
      const text = trimText(findSummaryFields().at(0).text());
      expect(text).toContain('Project : gitlab-policies/js6');
      expect(text).toContain('Reference : main');
      expect(text).toContain('Path : pipeline_execution_jobs.yml');
      expect(findSummaryHeader().text()).toBe('Enforce the following pipeline execution policy:');
    });

    it('renders the policy summary as a link for the project field', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      const link = findLink(findProjectSummary());
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe('/gitlab-policies/js6');
      expect(link.text()).toBe('gitlab-policies/js6');
    });

    it('renders the policy summary as a link for the file field', () => {
      createComponent({ propsData: { policy: mockProjectPipelineExecutionPolicy } });

      const link = findLink(findFileSummary());
      expect(link.exists()).toBe(true);
      expect(link.attributes('href')).toBe(
        '/path/to/project/-/blob/main/pipeline_execution_jobs.yml',
      );
      expect(link.text()).toBe('pipeline_execution_jobs.yml');
    });
  });

  describe('configuration', () => {
    it('renders default configuration row if there is no configuration in policy', () => {
      createComponent({
        propsData: { policy: mockProjectPipelineExecutionPolicy },
        provide: { glFeatures: { securityPoliciesSkipCi: true } },
      });

      expect(findConfigurationRow().exists()).toBe(true);
    });

    it('renders configuration row when there is a configuration', () => {
      createComponent({
        propsData: { policy: mockProjectPipelineExecutionWithConfigurationPolicy },
        provide: { glFeatures: { securityPoliciesSkipCi: true } },
      });

      expect(findConfigurationRow().exists()).toBe(true);
    });
  });
});
