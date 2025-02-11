import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import searchProjectMembers from '~/graphql_shared/queries/project_user_members_search.query.graphql';
import searchGroupMembers from '~/graphql_shared/queries/group_users_search.query.graphql';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import createMockApollo from 'helpers/mock_apollo_helper';
import UserSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/user_select.vue';
import { NAMESPACE_TYPES, USER_TYPE } from 'ee/security_orchestration/constants';

Vue.use(VueApollo);

const user = {
  id: 'gid://gitlab/User/1',
  name: 'Name 1',
  username: 'name.1',
  avatarUrl: 'https://www.gravatar.com/avatar/1234',
  __typename: 'UserCore',
};

const user2 = {
  id: 'gid://gitlab/User/2',
  name: 'Name 2',
  username: 'name.2',
  avatarUrl: 'https://www.gravatar.com/avatar/1235',
  __typename: 'UserCore',
};

const createProjectMemberResponse = (nodes) => ({
  data: {
    project: {
      id: 'gid://gitlab/Project/6',
      projectMembers: {
        nodes,
        __typename: 'MemberInterfaceConnection',
      },
      __typename: 'Project',
    },
  },
});

const DUPLICATE_PROJECT_MEMBER_RESPONSE = createProjectMemberResponse([
  { id: 'gid://gitlab/ProjectMember/1', user, __typename: 'ProjectMember' },
  { id: 'gid://gitlab/ProjectMember/2', user, __typename: 'ProjectMember' },
  { id: 'gid://gitlab/ProjectMember/3', user: user2, __typename: 'ProjectMember' },
]);

const GROUP_MEMBER_RESPONSE = {
  data: {
    workspace: {
      id: 'gid://gitlab/Group/6',
      users: {
        nodes: [
          {
            id: 'gid://gitlab/GroupMember/1',
            user: { ...user, webUrl: 'path/to/user', webPath: 'path/to/user', status: null },
            __typename: 'GroupMember',
          },
        ],
        pageInfo: {
          hasNextPage: false,
          startCursor: 'start-cursor',
          endCursor: 'end-cursor',
          __typename: 'PageInfo',
        },
        __typename: 'GroupMemberConnection',
      },
      __typename: 'Group',
    },
  },
};

describe('UserSelect component', () => {
  let wrapper;
  const namespacePath = 'path/to/namespace';
  const namespaceType = NAMESPACE_TYPES.PROJECT;
  const projectSearchQueryHandlerSuccess = jest
    .fn()
    .mockResolvedValue(DUPLICATE_PROJECT_MEMBER_RESPONSE);
  const groupSearchQueryHandlerSuccess = jest.fn().mockResolvedValue(GROUP_MEMBER_RESPONSE);

  const createComponent = ({ propsData = {}, provide = {} } = {}) => {
    const fakeApollo = createMockApollo([
      [searchProjectMembers, projectSearchQueryHandlerSuccess],
      [searchGroupMembers, groupSearchQueryHandlerSuccess],
    ]);

    wrapper = shallowMountExtended(UserSelect, {
      apolloProvider: fakeApollo,
      propsData: {
        existingApprovers: [],
        ...propsData,
      },
      provide: {
        namespacePath,
        namespaceType,
        ...provide,
      },
      stubs: {
        GlCollapsibleListbox,
      },
    });
  };

  const findListbox = () => wrapper.findComponent(GlCollapsibleListbox);

  const waitForApolloAndVue = async () => {
    await nextTick();
    jest.runOnlyPendingTimers();
    await waitForPromises();
  };

  describe('default', () => {
    beforeEach(async () => {
      createComponent();
      await waitForApolloAndVue();
    });

    it('displays the correct listbox toggle class', () => {
      expect(findListbox().props('toggleClass')).toEqual([{ '!gl-shadow-inner-1-red-500': false }]);
    });

    it('removes duplicates from user request', () => {
      expect(findListbox().props('items')).toEqual([
        { ...user, id: user.id, text: user.name, username: `@${user.username}`, value: user.id },
        {
          ...user2,
          id: user2.id,
          text: user2.name,
          username: `@${user2.username}`,
          value: user2.id,
        },
      ]);
    });

    it('filters users when search is performed in listbox', async () => {
      expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledWith({
        fullPath: namespacePath,
        search: '',
      });

      const searchTerm = 'test';
      findListbox().vm.$emit('search', searchTerm);
      await waitForApolloAndVue();

      expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledWith({
        fullPath: namespacePath,
        search: searchTerm,
      });
    });

    it('emits when a user is selected', async () => {
      findListbox().vm.$emit('select', [user.id]);
      await nextTick();
      expect(findListbox().props('toggleText')).toBe('Name 1');
      expect(wrapper.emitted('updateSelectedApprovers')).toEqual([
        [
          [
            {
              ...user,
              id: getIdFromGraphQLId(user.id),
              text: user.name,
              type: USER_TYPE,
              username: `@${user.username}`,
              value: user.id,
            },
          ],
        ],
      ]);
    });

    it('emits when a user is deselected', async () => {
      findListbox().vm.$emit('select', [user.id]);
      await nextTick();
      findListbox().vm.$emit('select', []);
      await nextTick();
      expect(wrapper.emitted('updateSelectedApprovers')[1]).toEqual([[]]);
    });
  });

  describe('custom props', () => {
    beforeEach(() => {
      createComponent({ propsData: { state: false } });
    });

    it('displays the correct listbox toggle class', () => {
      expect(findListbox().props('toggleClass')).toEqual([{ '!gl-shadow-inner-1-red-500': true }]);
    });
  });

  it('requests project members at the project-level', async () => {
    createComponent();
    await waitForApolloAndVue();
    expect(projectSearchQueryHandlerSuccess).toHaveBeenCalledWith({
      fullPath: namespacePath,
      search: '',
    });
  });

  it('requests group members at the group-level', async () => {
    createComponent({ provide: { namespaceType: NAMESPACE_TYPES.GROUP } });
    await waitForApolloAndVue();
    expect(groupSearchQueryHandlerSuccess).toHaveBeenCalledWith({
      fullPath: namespacePath,
      search: '',
    });
  });

  it('sets correct toggle text when only approver id is provided', async () => {
    createComponent({ propsData: { existingApprovers: [1, 2] } });
    await waitForApolloAndVue();
    await waitForPromises();

    expect(findListbox().props('toggleText')).toBe('Name 1, Name 2');
  });

  describe('preserving selection', () => {
    it('preserves initial selection after search', async () => {
      createComponent({
        propsData: {
          existingApprovers: [user],
        },
      });

      await waitForApolloAndVue();

      expect(findListbox().props('items')).toHaveLength(2);
      expect(findListbox().props('toggleText')).toBe(user.name);

      await findListbox().vm.$emit('search', user2.name);

      expect(findListbox().props('items')).toHaveLength(1);
      expect(findListbox().props('selected')).toEqual([user.id]);

      await wrapper.findByTestId(`listbox-item-${user2.id}`).vm.$emit('select', true);

      expect(wrapper.emitted('updateSelectedApprovers')).toEqual([
        [
          [
            expect.objectContaining({ name: user.name }),
            expect.objectContaining({ name: user2.name }),
          ],
        ],
      ]);
    });
  });

  describe('disabled state', () => {
    it('renders disabled state', () => {
      createComponent({
        propsData: {
          disabled: true,
        },
      });

      expect(findListbox().props('disabled')).toBe(true);
    });
  });

  describe('reset selected users', () => {
    it('reset selected users when there are no selected users', async () => {
      createComponent({ propsData: { existingApprovers: [1, 2], resetOnEmpty: true } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual([
        'gid://gitlab/User/1',
        'gid://gitlab/User/2',
      ]);

      await wrapper.setProps({ existingApprovers: [] });

      expect(findListbox().props('selected')).toEqual([]);
    });

    it('update selected users when new users selected', async () => {
      createComponent({ propsData: { existingApprovers: [1], resetOnEmpty: true } });
      await waitForApolloAndVue();
      await waitForPromises();

      expect(findListbox().props('selected')).toEqual(['gid://gitlab/User/1']);

      await wrapper.setProps({ existingApprovers: [1, 2] });

      expect(findListbox().props('selected')).toEqual([
        'gid://gitlab/User/1',
        'gid://gitlab/User/2',
      ]);
    });
  });
});
