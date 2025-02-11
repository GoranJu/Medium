import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import getGroups from 'ee/security_orchestration/graphql/queries/get_groups_for_policies.query.graphql';
import getGroupProjects from 'ee/security_orchestration/graphql/queries/get_group_projects.query.graphql';
import getProjects from 'ee/security_orchestration/graphql/queries/get_projects.query.graphql';
import BaseItemsDropdown from 'ee/security_orchestration/components/shared/base_items_dropdown.vue';
import GroupProjectsDropdown from 'ee/security_orchestration/components/shared/group_projects_dropdown.vue';
import {
  generateMockGroups,
  generateMockProjects,
} from 'ee_jest/security_orchestration/mocks/mock_data';

describe('GroupProjectsDropdown', () => {
  let wrapper;
  let requestHandlers;

  const GROUP_FULL_PATH = 'gitlab-org';

  const defaultNodes = generateMockProjects([1, 2]);
  const defaultGroups = generateMockGroups([1, 2]);

  const defaultNodesIds = defaultNodes.map(({ id }) => id);
  const defaultGroupIds = defaultGroups.map(({ id }) => id);

  const mapItems = (items) =>
    items.map(({ id, name, fullPath }) => ({ value: id, text: name, fullPath }));

  const defaultPageInfo = {
    __typename: 'PageInfo',
    hasNextPage: false,
    hasPreviousPage: false,
    startCursor: null,
    endCursor: null,
  };

  const mockApolloHandlers = (
    nodes = defaultNodes,
    hasNextPage = false,
    groups = defaultGroups,
  ) => {
    return {
      getGroups: jest.fn().mockResolvedValue({
        data: {
          groups: {
            nodes: groups,
            pageInfo: { ...defaultPageInfo, hasNextPage },
          },
        },
      }),
      getProjects: jest.fn().mockResolvedValue({
        data: {
          projects: {
            nodes,
            pageInfo: { ...defaultPageInfo, hasNextPage },
          },
        },
      }),
      getGroupProjects: jest.fn().mockResolvedValue({
        data: {
          id: 1,
          group: {
            id: 2,
            projects: {
              nodes,
              pageInfo: { ...defaultPageInfo, hasNextPage },
            },
          },
        },
      }),
    };
  };

  const createMockApolloProvider = (handlers) => {
    Vue.use(VueApollo);

    requestHandlers = handlers;
    return createMockApollo([
      [getGroupProjects, requestHandlers.getGroupProjects],
      [getGroups, requestHandlers.getGroups],
      [getProjects, requestHandlers.getProjects],
    ]);
  };

  const createComponent = ({
    propsData = {},
    handlers = mockApolloHandlers(),
    stubs = {},
  } = {}) => {
    wrapper = shallowMountExtended(GroupProjectsDropdown, {
      apolloProvider: createMockApolloProvider(handlers),
      propsData: {
        groupFullPath: GROUP_FULL_PATH,
        ...propsData,
      },
      stubs,
    });
  };

  const findDropdown = () => wrapper.findComponent(BaseItemsDropdown);

  describe.each`
    groupsOnly | items
    ${false}   | ${defaultNodes}
    ${true}    | ${defaultGroups}
  `('selection', ({ groupsOnly, items }) => {
    beforeEach(() => {
      createComponent({
        propsData: {
          groupsOnly,
        },
      });
    });

    it('should render loading state', () => {
      expect(findDropdown().props('loading')).toBe(true);
    });

    it('should load items', async () => {
      await waitForPromises();
      expect(findDropdown().props('loading')).toBe(false);
      expect(findDropdown().props('items')).toEqual(mapItems(items));
    });

    it('should select items', async () => {
      const [{ id }] = items;

      await waitForPromises();
      findDropdown().vm.$emit('select', [id]);
      expect(wrapper.emitted('select')).toEqual([[[items[0]]]]);
    });
  });

  it.each`
    groupsOnly | items
    ${false}   | ${defaultNodes}
    ${true}    | ${defaultGroups}
  `('should select full items with full id format', async ({ groupsOnly, items }) => {
    createComponent({
      propsData: {
        useShortIdFormat: false,
        groupsOnly,
      },
    });

    const [{ id }] = items;

    await waitForPromises();
    findDropdown().vm.$emit('select', [id]);
    expect(wrapper.emitted('select')).toEqual([[[items[0]]]]);
  });

  describe.each`
    groupsOnly | ids
    ${false}   | ${defaultNodesIds}
    ${true}    | ${defaultGroupIds}
  `('selected items', ({ groupsOnly, ids }) => {
    const type = groupsOnly ? 'groups' : 'projects';

    beforeEach(() => {
      createComponent({
        propsData: {
          selected: ids,
          groupsOnly,
        },
      });
    });

    it(`should be possible to preselect ${type}`, async () => {
      await waitForPromises();
      expect(findDropdown().props('selected')).toEqual(ids);
    });
  });

  describe('selected items that does not exist', () => {
    it('filters selected projects that does not exist', async () => {
      createComponent({
        propsData: {
          selected: ['one', 'two'],
          useShortIdFormat: false,
        },
      });

      await waitForPromises();
      findDropdown().vm.$emit('select', [defaultNodesIds[0]]);

      expect(wrapper.emitted('select')).toEqual([[[defaultNodes[0]]]]);
    });
  });

  describe.each`
    type         | groupsOnly | ids                | items            | handlers
    ${'project'} | ${false}   | ${defaultNodesIds} | ${defaultNodes}  | ${mockApolloHandlers()}
    ${'group'}   | ${true}    | ${defaultGroupIds} | ${defaultGroups} | ${mockApolloHandlers([], false, defaultGroups)}
  `('select single $type', ({ type, groupsOnly, ids, items, handlers }) => {
    it('support single selection mode', async () => {
      createComponent({
        propsData: {
          multiple: false,
          groupsOnly,
        },
        handlers,
      });

      await waitForPromises();

      findDropdown().vm.$emit('select', ids[0]);
      expect(wrapper.emitted('select')).toEqual([[items[0]]]);
    });

    it(`should render single selected ${type}`, async () => {
      createComponent({
        propsData: {
          multiple: false,
          selected: ids[0],
          groupsOnly,
        },
        handlers,
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(ids[0]);
    });
  });

  describe('when there is more than a page of projects', () => {
    describe('when bottom reached on scrolling', () => {
      describe('groups', () => {
        it('makes a query to fetch more groups', async () => {
          createComponent({
            propsData: { groupsOnly: true },
            handlers: mockApolloHandlers([], true, []),
          });
          await waitForPromises();

          findDropdown().vm.$emit('bottom-reached');
          expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(0);
          expect(requestHandlers.getGroups).toHaveBeenCalledTimes(2);
        });
      });

      describe('projects', () => {
        it('makes a query to fetch more projects', async () => {
          createComponent({ handlers: mockApolloHandlers([], true) });
          await waitForPromises();

          findDropdown().vm.$emit('bottom-reached');
          expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(2);
          expect(requestHandlers.getGroups).toHaveBeenCalledTimes(0);
        });

        it('loads all projects when property is set to true', async () => {
          createComponent({
            propsData: { loadAllProjects: true },
          });
          await waitForPromises();

          expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(0);
          expect(requestHandlers.getProjects).toHaveBeenCalledWith({
            projectIds: null,
            search: '',
          });
        });

        it('loads more projects when bottom is reached', async () => {
          createComponent({
            propsData: { loadAllProjects: true },
            handlers: mockApolloHandlers({ hasNextPage: true }),
          });
          await waitForPromises();

          findDropdown().vm.$emit('bottom-reached');
          expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(0);
          expect(requestHandlers.getProjects).toHaveBeenCalledTimes(2);
          expect(requestHandlers.getProjects).toHaveBeenNthCalledWith(2, {
            after: undefined,
            projectIds: null,
            search: '',
          });
        });
      });

      describe('groups ids', () => {
        it('filters projects by group ids', async () => {
          createComponent({
            propsData: {
              groupIds: [defaultNodes[0].group.id],
            },
          });
          await waitForPromises();

          expect(findDropdown().props('items')).toEqual(mapItems([defaultNodes[0]]));
        });
      });

      describe('when the fetch query throws an error', () => {
        it.each`
          groupsOnly | event
          ${false}   | ${'projects-query-error'}
          ${true}    | ${'groups-query-error'}
        `('emits an error event', async ({ groupsOnly, event }) => {
          createComponent({
            propsData: {
              groupsOnly,
            },
            handlers: {
              getGroupProjects: jest.fn().mockRejectedValue({}),
            },
          });
          await waitForPromises();
          expect(wrapper.emitted(event)).toHaveLength(1);
        });
      });
    });

    describe('when a query is loading a new page of projects', () => {
      it.each`
        groupsOnly | handlers
        ${false}   | ${mockApolloHandlers([], true)}
        ${true}    | ${mockApolloHandlers([], true, [])}
      `('should render the loading spinner', async ({ groupsOnly, handlers }) => {
        createComponent({ propsData: { groupsOnly }, handlers });
        await waitForPromises();

        findDropdown().vm.$emit('bottom-reached');
        await nextTick();

        expect(findDropdown().props('loading')).toBe(true);
      });
    });
  });

  describe('full id format', () => {
    it.each`
      groupsOnly | ids
      ${false}   | ${defaultNodesIds}
      ${true}    | ${defaultGroupIds}
    `('should render selected ids in full format', async ({ groupsOnly, ids }) => {
      createComponent({
        propsData: {
          selected: ids,
          useShortIdFormat: false,
          groupsOnly,
        },
      });

      await waitForPromises();

      expect(findDropdown().props('selected')).toEqual(ids);
    });
  });

  describe('validation', () => {
    it.each([false, true])('renders default dropdown when validation passes', (groupsOnly) => {
      createComponent({
        propsData: {
          state: true,
          groupsOnly,
        },
      });

      expect(findDropdown().props('variant')).toEqual('default');
      expect(findDropdown().props('category')).toEqual('primary');
    });

    it.each([false, true])('renders danger dropdown when validation passes', (groupsOnly) => {
      createComponent({
        propsData: {
          groupsOnly,
        },
      });

      expect(findDropdown().props('variant')).toEqual('danger');
      expect(findDropdown().props('category')).toEqual('secondary');
    });
  });

  describe('select all', () => {
    describe.each(['groups', 'projects'])('items', (itemType) => {
      it(`selects all ${itemType}`, async () => {
        const groupsOnly = itemType === 'groups';
        const nodes = groupsOnly ? defaultGroups : defaultNodes;
        const ids = groupsOnly ? defaultGroupIds : defaultNodesIds;

        createComponent({
          propsData: {
            groupsOnly,
          },
        });
        await waitForPromises();

        findDropdown().vm.$emit('select-all', ids);

        expect(wrapper.emitted('select')).toEqual([[nodes]]);
      });

      it('resets all groups', async () => {
        createComponent({
          propsData: {
            groupsOnly: true,
          },
        });

        await waitForPromises();

        findDropdown().vm.$emit('reset');

        expect(wrapper.emitted('select')).toEqual([[[]]]);
      });
    });
  });

  describe('selection after search', () => {
    describe('groups', () => {
      it('should add projects to existing selection after search', async () => {
        const moreNodes = generateMockGroups([1, 2, 3, 44, 444, 4444]);
        createComponent({
          propsData: {
            selected: defaultGroupIds,
            groupsOnly: true,
          },
          handlers: mockApolloHandlers([], false, moreNodes),
          stubs: {
            BaseItemsDropdown,
            GlCollapsibleListbox,
          },
        });

        await waitForPromises();

        expect(findDropdown().props('selected')).toEqual(defaultGroupIds);

        findDropdown().vm.$emit('search', '4');
        await waitForPromises();

        expect(requestHandlers.getGroups).toHaveBeenCalledWith({
          search: '4',
        });
        expect(requestHandlers.getGroupProjects).toHaveBeenCalledTimes(0);

        await waitForPromises();

        await wrapper.findByTestId(`listbox-item-${moreNodes[3].id}`).vm.$emit('select', true);

        expect(wrapper.emitted('select')).toEqual([[[...defaultGroups, moreNodes[3]]]]);
      });
    });

    describe('projects', () => {
      it('should add projects to existing selection after search', async () => {
        const moreNodes = generateMockProjects([1, 2, 3, 44, 444, 4444]);
        createComponent({
          propsData: {
            selected: defaultNodesIds,
          },
          handlers: mockApolloHandlers(moreNodes),
          stubs: {
            BaseItemsDropdown,
            GlCollapsibleListbox,
          },
        });

        await waitForPromises();

        expect(findDropdown().props('selected')).toEqual(defaultNodesIds);

        findDropdown().vm.$emit('search', '4');
        await waitForPromises();

        expect(requestHandlers.getGroups).toHaveBeenCalledTimes(0);
        expect(requestHandlers.getGroupProjects).toHaveBeenCalledWith({
          fullPath: GROUP_FULL_PATH,
          projectIds: null,
          search: '4',
        });

        await waitForPromises();
        await wrapper.findByTestId(`listbox-item-${moreNodes[3].id}`).vm.$emit('select', true);

        expect(wrapper.emitted('select')).toEqual([[[...defaultNodes, moreNodes[3]]]]);
      });
    });

    it('should search projects by fullPath', async () => {
      createComponent({
        propsData: { loadAllProjects: true },
      });
      await waitForPromises();

      findDropdown().vm.$emit('search', 'project-1-full-path');
      await waitForPromises();

      expect(findDropdown().props('items')).toEqual(mapItems([defaultNodes[0]]));
      expect(requestHandlers.getProjects).toHaveBeenCalledWith({
        projectIds: null,
        search: 'project-1-full-path',
      });
    });
  });
});
