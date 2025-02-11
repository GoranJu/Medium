import { GlAvatarLabeled, GlFormRadio, GlFormRadioGroup, GlCollapsibleListbox } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import BoardAddNewColumn, { listTypeInfo } from 'ee/boards/components/board_add_new_column.vue';
import projectBoardMilestonesQuery from '~/boards/graphql/project_board_milestones.query.graphql';
import searchIterationQuery from 'ee/issues/list/queries/search_iterations.query.graphql';
import createBoardListMutation from 'ee_else_ce/boards/graphql/board_list_create.mutation.graphql';
import boardLabelsQuery from '~/boards/graphql/board_labels.query.graphql';
import usersAutocompleteQuery from '~/graphql_shared/queries/users_autocomplete.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import BoardAddNewColumnForm from '~/boards/components/board_add_new_column_form.vue';
import IterationTitle from 'ee/iterations/components/iteration_title.vue';
import { ListType } from '~/boards/constants';
import * as cacheUpdates from '~/boards/graphql/cache_updates';
import { getIterationPeriod } from 'ee/iterations/utils';
import { createBoardListResponse, labelsQueryResponse } from 'jest/boards/mock_data';
import {
  mockAssignees,
  mockIterations,
  assigneesQueryResponse,
  milestonesQueryResponse,
  iterationsQueryResponse,
} from '../mock_data';

Vue.use(VueApollo);

describe('BoardAddNewColumn', () => {
  let wrapper;
  let mockApollo;

  const createBoardListQueryHandler = jest.fn().mockResolvedValue(createBoardListResponse);
  const labelsQueryHandler = jest.fn().mockResolvedValue(labelsQueryResponse);
  const milestonesQueryHandler = jest.fn().mockResolvedValue(milestonesQueryResponse);
  const assigneesQueryHandler = jest.fn().mockResolvedValue(assigneesQueryResponse);
  const iterationQueryHandler = jest.fn().mockResolvedValue(iterationsQueryResponse);
  const errorMessageMilestones = 'Failed to fetch milestones';
  const milestonesQueryHandlerFailure = jest
    .fn()
    .mockRejectedValue(new Error(errorMessageMilestones));
  const errorMessageAssignees = 'Failed to fetch assignees';
  const assigneesQueryHandlerFailure = jest
    .fn()
    .mockRejectedValue(new Error(errorMessageAssignees));
  const errorMessageIterations = 'Failed to fetch iterations';
  const iterationsQueryHandlerFailure = jest
    .fn()
    .mockRejectedValue(new Error(errorMessageIterations));

  const findDropdown = () => wrapper.findComponent(GlCollapsibleListbox);
  const selectItem = (id) => {
    findDropdown().vm.$emit('select', id);
  };

  const mountComponent = ({
    selectedId,
    provide = {},
    labelsHandler = labelsQueryHandler,
    milestonesHandler = milestonesQueryHandler,
    assigneesHandler = assigneesQueryHandler,
    iterationHandler = iterationQueryHandler,
  } = {}) => {
    mockApollo = createMockApollo([
      [boardLabelsQuery, labelsHandler],
      [usersAutocompleteQuery, assigneesHandler],
      [projectBoardMilestonesQuery, milestonesHandler],
      [searchIterationQuery, iterationHandler],
      [createBoardListMutation, createBoardListQueryHandler],
    ]);

    wrapper = shallowMountExtended(BoardAddNewColumn, {
      apolloProvider: mockApollo,
      propsData: {
        listQueryVariables: {},
        boardId: 'gid://gitlab/Board/1',
        lists: {},
      },
      stubs: {
        BoardAddNewColumnForm,
        GlFormRadio,
        GlFormRadioGroup,
        IterationTitle,
        GlCollapsibleListbox,
      },
      data() {
        return {
          selectedId,
        };
      },
      provide: {
        scopedLabelsAvailable: true,
        milestoneListsAvailable: true,
        assigneeListsAvailable: true,
        iterationListsAvailable: true,
        isEpicBoard: false,
        issuableType: 'issue',
        fullPath: 'gitlab-org/gitlab',
        boardType: 'project',
        ...provide,
      },
    });

    // trigger change event
    if (selectedId) {
      selectItem(selectedId);
    }

    // Necessary for cache update
    mockApollo.clients.defaultClient.cache.writeQuery = jest.fn();
  };

  const findForm = () => wrapper.findComponent(BoardAddNewColumnForm);
  const cancelButton = () => wrapper.findByTestId('cancelAddNewColumn');
  const submitButton = () => wrapper.findByTestId('addNewColumnButton');
  const findIterationItemAt = (i) => wrapper.findAllByTestId('new-column-iteration-item').at(i);
  const listTypeSelect = (type) => {
    const radio = wrapper
      .findAllComponents(GlFormRadio)
      .filter((r) => r.attributes('value') === type)
      .at(0);
    radio.element.value = type;
    radio.vm.$emit('change', type);
  };
  const selectIteration = async () => {
    listTypeSelect(ListType.iteration);

    await nextTick();
  };

  const expectIterationWithTitle = () => {
    expect(findIterationItemAt(1).text()).toContain(getIterationPeriod(mockIterations[1]));
    expect(findIterationItemAt(1).text()).toContain(mockIterations[1].title);
  };

  const expectIterationWithoutTitle = () => {
    expect(findIterationItemAt(0).text()).toContain(getIterationPeriod(mockIterations[0]));
    expect(findIterationItemAt(0).findComponent(IterationTitle).exists()).toBe(false);
  };

  beforeEach(() => {
    cacheUpdates.setError = jest.fn();
  });

  it('clicking cancel hides the form', () => {
    mountComponent();

    cancelButton().vm.$emit('click');

    expect(wrapper.emitted('setAddColumnFormVisibility')).toEqual([[false]]);
  });

  it('renders GlCollapsibleListbox with search field', () => {
    mountComponent();

    expect(findDropdown().exists()).toBe(true);
    expect(findDropdown().props('searchable')).toBe(true);
  });

  describe('Add list button', () => {
    it('is enabled if no item is selected', () => {
      mountComponent();

      expect(submitButton().props('disabled')).toBe(false);
    });
  });

  describe('List types', () => {
    describe('assignee list', () => {
      beforeEach(async () => {
        mountComponent();
        listTypeSelect(ListType.assignee);

        await nextTick();
      });

      it('sets assignee placeholder text in form', () => {
        expect(findForm().props('searchLabel')).toBe(BoardAddNewColumn.i18n.value);
        expect(findDropdown().props('searchPlaceholder')).toBe(
          listTypeInfo.assignee.searchPlaceholder,
        );
      });

      it('shows list of assignees', () => {
        const userList = wrapper.findAllComponents(GlAvatarLabeled);

        const [firstUser] = mockAssignees;

        expect(userList).toHaveLength(mockAssignees.length);
        expect(userList.at(0).props()).toMatchObject({
          label: firstUser.name,
          subLabel: `@${firstUser.username}`,
        });
      });
    });

    describe('iteration list', () => {
      beforeEach(async () => {
        mountComponent();
        await selectIteration();
      });

      it('sets iteration placeholder text in form', () => {
        expect(findForm().props('searchLabel')).toBe(BoardAddNewColumn.i18n.value);
        expect(findDropdown().props('searchPlaceholder')).toBe(
          listTypeInfo.iteration.searchPlaceholder,
        );
      });

      it('shows list of iterations', () => {
        const itemList = findDropdown().props('items');

        expect(itemList).toHaveLength(mockIterations.length);
        expectIterationWithoutTitle();
        expectIterationWithTitle();
      });
    });

    describe('when fetch milestones query fails', () => {
      beforeEach(async () => {
        mountComponent({
          milestonesHandler: milestonesQueryHandlerFailure,
        });
        listTypeSelect(ListType.milestone);

        await nextTick();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });

    describe('when fetch assignees query fails', () => {
      beforeEach(async () => {
        mountComponent({
          assigneesHandler: assigneesQueryHandlerFailure,
        });
        listTypeSelect(ListType.assignee);

        await nextTick();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });

    describe('when fetch iterations query fails', () => {
      beforeEach(async () => {
        mountComponent({
          iterationHandler: iterationsQueryHandlerFailure,
        });
        await selectIteration();
      });

      it('sets error', async () => {
        findDropdown().vm.$emit('show');

        await waitForPromises();
        expect(cacheUpdates.setError).toHaveBeenCalled();
      });
    });
  });
});
