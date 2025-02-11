import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import ScopeProjectSelector from 'ee/security_orchestration/components/policy_editor/scope/scope_project_selector.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import { generateMockProjects } from 'ee_jest/security_orchestration/mocks/mock_data';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import { EXCEPT_PROJECTS } from 'ee/security_orchestration/components/policy_editor/scope/constants';

describe('ScopeProjectSelector', () => {
  let wrapper;

  const projects = generateMockProjects([1, 2]);
  const mappedProjects = projects.map(({ id }) => ({ id: getIdFromGraphQLId(id) }));

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(ScopeProjectSelector, {
      propsData: {
        groupFullPath: 'gitlab-org',
        projects: { excluding: [] },
        ...propsData,
      },
    });
  };

  const findExceptionTypeSelector = () => wrapper.findByTestId('exception-type');
  const findGroupProjectsDropdown = () => wrapper.findComponent(GroupProjectsDropdown);

  describe('default rendering', () => {
    it('renders exceptions type selector', () => {
      createComponent();

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
    });

    it('renders exceptions type selector with empty projects', () => {
      createComponent({
        projects: {},
      });

      expect(findExceptionTypeSelector().exists()).toBe(true);
      expect(findGroupProjectsDropdown().exists()).toBe(false);
    });
  });

  describe('renders projects selector', () => {
    it('renders projects selector when exception type is selected', () => {
      createComponent({
        exceptionType: EXCEPT_PROJECTS,
      });

      expect(findGroupProjectsDropdown().exists()).toBe(true);
    });

    it('renders projects selector when exceptions are disabled', () => {
      createComponent({
        projects: {
          including: [],
        },
      });

      expect(findExceptionTypeSelector().exists()).toBe(false);
      expect(findGroupProjectsDropdown().exists()).toBe(true);
    });
  });

  describe('project selection', () => {
    it('should select exception projects', () => {
      createComponent({
        exceptionType: EXCEPT_PROJECTS,
      });

      findGroupProjectsDropdown().vm.$emit('select', projects);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            projects: {
              excluding: mappedProjects,
            },
          },
        ],
      ]);
    });

    it('should select specific projects', () => {
      createComponent({
        projects: {
          including: [],
        },
      });

      findGroupProjectsDropdown().vm.$emit('select', projects);

      expect(wrapper.emitted('changed')).toEqual([
        [
          {
            projects: {
              including: mappedProjects,
            },
          },
        ],
      ]);
    });
  });

  describe('selected projects', () => {
    it.each`
      key            | projectType    | hasExceptions
      ${'excluding'} | ${'exception'} | ${true}
      ${'including'} | ${'specific'}  | ${false}
    `('renders selected $projectType projects', ({ key, hasExceptions }) => {
      createComponent({
        projects: {
          [key]: mappedProjects,
        },
        exceptionType: EXCEPT_PROJECTS,
      });

      expect(findExceptionTypeSelector().exists()).toBe(hasExceptions);
      expect(findGroupProjectsDropdown().props('selected')).toEqual([
        projects[0].id,
        projects[1].id,
      ]);
    });
  });

  describe('error state', () => {
    it('emits error when projects loading fails', () => {
      createComponent({
        projects: {
          including: mappedProjects,
        },
      });

      findGroupProjectsDropdown().vm.$emit('projects-query-error');

      expect(wrapper.emitted('error')).toEqual([['Failed to load group projects']]);
    });

    it('does not render initial error state for a dropdown', () => {
      createComponent({
        projects: {
          including: mappedProjects,
        },
      });
      expect(findGroupProjectsDropdown().props('state')).toBe(true);
    });

    it('renders error state for a dropdown when form is dirty', () => {
      createComponent({
        isDirty: true,
        projects: {
          including: [],
        },
      });
      expect(findGroupProjectsDropdown().props('state')).toBe(false);
    });
  });

  describe('select exceptions', () => {
    it('selects exception type', () => {
      createComponent();

      findExceptionTypeSelector().vm.$emit('select', EXCEPT_PROJECTS);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPT_PROJECTS]]);
    });
  });
});
