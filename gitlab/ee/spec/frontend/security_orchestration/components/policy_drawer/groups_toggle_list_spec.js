import { GlLink } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import GroupsToggleList from 'ee/security_orchestration/components/policy_drawer/groups_toggle_list.vue';

describe('GroupsToggleList', () => {
  let wrapper;

  const mockedGroups = [
    { id: 1, name: 'group 1' },
    { id: 2, name: 'group 2' },
  ];
  const mockedProjects = [
    { id: 1, name: 'project 1' },
    { id: 2, name: 'project 2' },
  ];

  const createComponent = ({ propsData = {} } = {}) => {
    wrapper = shallowMountExtended(GroupsToggleList, {
      propsData: {
        groups: mockedGroups,
        ...propsData,
      },
    });
  };

  const findGroupListHeader = () => wrapper.findByTestId('groups-list-header');
  const findGroupListInlineHeader = () => wrapper.findByTestId('groups-list-inline-header');
  const findProjectsList = () => wrapper.findByTestId('projects-list');
  const findGroupsList = () => wrapper.findByTestId('groups-list');
  const findProjectListHeader = () => wrapper.findByTestId('projects-list-header');
  const findAllGroupItems = () => wrapper.findAllByTestId('group-item');
  const findAllProjectItems = () => wrapper.findAllByTestId('project-item');
  const findAllLinks = () => wrapper.findAllComponents(GlLink);

  describe('default rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders header and group list', () => {
      expect(findAllGroupItems()).toHaveLength(2);
      expect(findGroupListHeader().text()).toBe('All projects in 2 groups:');
      expect(findGroupsList().exists()).toBe(true);
      expect(findProjectsList().exists()).toBe(false);
      expect(findProjectListHeader().exists()).toBe(false);
    });
  });

  describe('single group', () => {
    it('renders correct header for single group', () => {
      createComponent({
        propsData: {
          groups: [mockedGroups[0]],
        },
      });

      expect(findGroupListHeader().text()).toBe('All projects in 1 group:');
    });
  });

  describe('exception projects', () => {
    it('renders list with exception projects', () => {
      createComponent({
        propsData: {
          projects: mockedProjects,
        },
      });

      expect(findAllGroupItems()).toHaveLength(2);
      expect(findGroupListHeader().text()).toBe('All projects in 2 groups, with exclusions:');
      expect(findAllProjectItems()).toHaveLength(2);
    });
  });

  describe('inline list', () => {
    it('renders only header in inline mode', () => {
      createComponent({
        propsData: {
          inlineList: true,
        },
      });

      expect(findProjectsList().exists()).toBe(false);
      expect(findGroupsList().exists()).toBe(false);
      expect(findGroupListHeader().exists()).toBe(false);
      expect(findGroupListInlineHeader().text()).toBe('All projects in linked groups (2 groups)');
    });

    it('renders only default inline header when group list is empty', () => {
      createComponent({
        propsData: {
          inlineList: true,
          groups: [],
        },
      });

      expect(findGroupListInlineHeader().text()).toBe('All projects in linked groups');
    });
  });

  describe('links', () => {
    it('renders lists with links', () => {
      createComponent({
        propsData: {
          projects: mockedProjects,
          isLink: true,
        },
      });

      expect(findGroupsList().findAllComponents(GlLink).at(0).props('href')).toBe(
        mockedGroups[0].full_path,
      );

      expect(findGroupsList().findAllComponents(GlLink).at(1).props('href')).toBe(
        mockedGroups[1].full_path,
      );

      expect(findProjectsList().findAllComponents(GlLink).at(0).props('href')).toBe(
        mockedProjects[0].full_path,
      );

      expect(findProjectsList().findAllComponents(GlLink).at(1).props('href')).toBe(
        mockedProjects[1].full_path,
      );

      expect(findAllLinks()).toHaveLength(mockedGroups.length + mockedProjects.length);
    });
  });
});
