import * as urlUtils from '~/lib/utils/url_utility';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import App from 'ee/security_orchestration/components/policy_editor/app.vue';
import PolicyTypeSelector from 'ee/security_orchestration/components/policy_editor/policy_type_selector.vue';
import EditorWrapper from 'ee/security_orchestration/components/policy_editor/editor_wrapper.vue';

describe('App component', () => {
  let wrapper;

  const findPolicySelection = () => wrapper.findComponent(PolicyTypeSelector);
  const findPolicyEditor = () => wrapper.findComponent(EditorWrapper);
  const findTitle = () => wrapper.findByTestId('page-heading').text();

  const factory = ({ provide = {} } = {}) => {
    wrapper = shallowMountExtended(App, {
      provide: { assignedPolicyProject: {}, ...provide },
      stubs: { PageHeading },
    });
  };

  describe('rendering', () => {
    it('displays the policy selection when there is no query parameter', () => {
      factory();
      expect(findPolicySelection().exists()).toBe(true);
      expect(findPolicyEditor().exists()).toBe(false);
    });

    it('displays the policy editor when there is a type query parameter', () => {
      jest
        .spyOn(urlUtils, 'getParameterByName')
        .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS.approval.urlParameter);
      factory({ provide: { existingPolicy: { id: 'policy-id', value: 'approval' } } });
      expect(findPolicySelection().exists()).toBe(false);
      expect(findPolicyEditor().exists()).toBe(true);
    });
  });

  describe('page title', () => {
    describe.each`
      value                  | titleSuffix
      ${'approval'}          | ${'merge request approval policy'}
      ${'scanExecution'}     | ${'scan execution policy'}
      ${'pipelineExecution'} | ${'pipeline execution policy'}
    `('$titleSuffix', ({ titleSuffix, value }) => {
      beforeEach(() => {
        jest
          .spyOn(urlUtils, 'getParameterByName')
          .mockReturnValue(POLICY_TYPE_COMPONENT_OPTIONS[value].urlParameter);
      });

      it('displays for a new policy', () => {
        factory();
        expect(findTitle()).toBe(`New ${titleSuffix}`);
      });

      it('displays for an existing policy', () => {
        factory({ provide: { existingPolicy: { id: 'policy-id', value } } });
        expect(findTitle()).toBe(`Edit ${titleSuffix}`);
      });
    });

    describe('invalid url parameter', () => {
      beforeEach(() => {
        jest.spyOn(urlUtils, 'getParameterByName').mockReturnValue('invalid');
      });

      it('displays for a new policy', () => {
        factory();
        expect(findTitle()).toBe('New policy');
      });

      it('displays for an existing policy', () => {
        factory({ provide: { existingPolicy: { id: 'policy-id', value: 'scanResult' } } });
        expect(findTitle()).toBe('Edit policy');
      });
    });
  });
});
