import { GlEmptyState } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import createMockApollo from 'helpers/mock_apollo_helper';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import EmptyStateWithAnyIssues from '~/issues/list/components/empty_state_with_any_issues.vue';
import CreateWorkItemModal from '~/work_items/components/create_work_item_modal.vue';
import WorkItemsListApp from '~/work_items/pages/work_items_list_app.vue';
import EEWorkItemsListApp from 'ee/work_items/pages/work_items_list_app.vue';
import { CREATED_DESC } from '~/issues/list/constants';
import { WORK_ITEM_TYPE_ENUM_EPIC, WORK_ITEM_TYPE_ENUM_ISSUE } from '~/work_items/constants';
import getWorkItemsQuery from '~/work_items/graphql/list/get_work_items.query.graphql';
import workItemBulkUpdateMutation from '~/work_items/graphql/work_item_bulk_update.mutation.graphql';
import workItemParent from 'ee/work_items/graphql/list/work_item_parent.query.graphql';
import { groupWorkItemsQueryResponse } from 'jest/work_items/mock_data';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';
import waitForPromises from 'helpers/wait_for_promises';
import EpicsListBulkEditSidebar from 'ee/epics_list/components/epics_list_bulk_edit_sidebar.vue';
import { workItemParent as workItemParentResponse } from '../../mock_data';

const skipReason = new SkipReason({
  name: 'WorkItemsListApp EE component',
  reason: 'Caught error after test environment was torn down',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/478775',
});

describeSkipVue3(skipReason, () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;

  Vue.use(VueApollo);

  const findCreateWorkItemModal = () => wrapper.findComponent(CreateWorkItemModal);
  const findListEmptyState = () => wrapper.findComponent(EmptyStateWithAnyIssues);
  const findPageEmptyState = () => wrapper.findComponent(GlEmptyState);
  const findWorkItemsListApp = () => wrapper.findComponent(WorkItemsListApp);
  const findBulkEditStartButton = () => wrapper.findByTestId('bulk-edit-start-button');
  const findBulkEditSidebar = () => wrapper.findComponent(EpicsListBulkEditSidebar);

  const baseProvide = {
    groupIssuesPath: 'groups/gitlab-org/-/issues',
    fullPath: 'gitlab-org',
  };

  const extendedProvide = {
    autocompleteAwardEmojisPath: '/emojis/please',
    labelsManagePath: '/labels/please',
    labelsFetchPath: '/labels/please',
    initialSort: CREATED_DESC,
    isGroup: true,
    isSignedIn: true,
    hasOkrsFeature: true,
    hasQualityManagementFeature: true,
    hasIssuableHealthStatusFeature: true,
  };

  const mountComponent = ({
    hasEpicsFeature = true,
    showNewIssueLink = true,
    canBulkEditEpics = true,
    bulkUpdateMutationEnabled = true,
    isGroup = true,
    workItemType = WORK_ITEM_TYPE_ENUM_EPIC,
    props = {},
  } = {}) => {
    wrapper = shallowMountExtended(EEWorkItemsListApp, {
      provide: {
        hasEpicsFeature,
        showNewIssueLink,
        canBulkEditEpics,
        isGroup,
        workItemType,
        glFeatures: {
          bulkUpdateWorkItemsMutation: bulkUpdateMutationEnabled,
        },
        ...baseProvide,
      },
      stubs: {
        EmptyStateWithoutAnyIssues: {
          template: '<div></div>',
        },
      },
      propsData: {
        ...props,
      },
    });
  };

  const getWorkitemsQueryHandler = jest.fn().mockResolvedValue(groupWorkItemsQueryResponse);
  const workItemParentQueryHandler = jest.fn().mockResolvedValue(workItemParentResponse);
  const workItemBulkUpdateHandler = jest.fn();

  const deepMountComponent = async ({
    hasEpicsFeature = true,
    showNewIssueLink = true,
    canBulkEditEpics = true,
    bulkUpdateMutationEnabled = true,
    workItemType = WORK_ITEM_TYPE_ENUM_EPIC,
  } = {}) => {
    wrapper = mountExtended(EEWorkItemsListApp, {
      apolloProvider: createMockApollo([
        [getWorkItemsQuery, getWorkitemsQueryHandler],
        [workItemParent, workItemParentQueryHandler],
        [workItemBulkUpdateMutation, workItemBulkUpdateHandler],
      ]),
      provide: {
        hasEpicsFeature,
        showNewIssueLink,
        canBulkEditEpics,
        workItemType,
        glFeatures: {
          bulkUpdateWorkItemsMutation: bulkUpdateMutationEnabled,
        },
        ...baseProvide,
        ...extendedProvide,
      },
      stubs: {
        IssuableItem: true,
        IssueCardTimeInfo: true,
        IssueHealthStatus: true,
      },
    });

    await waitForPromises();
  };

  describe('create-work-item modal', () => {
    describe.each`
      hasEpicsFeature | showNewIssueLink | exists
      ${false}        | ${false}         | ${false}
      ${true}         | ${false}         | ${false}
      ${false}        | ${true}          | ${false}
      ${true}         | ${true}          | ${true}
    `(
      'when hasEpicsFeature=$hasEpicsFeature and showNewIssueLink=$showNewIssueLink',
      ({ hasEpicsFeature, showNewIssueLink, exists }) => {
        it(`${exists ? 'renders' : 'does not render'}`, () => {
          mountComponent({ hasEpicsFeature, showNewIssueLink });

          expect(findCreateWorkItemModal().exists()).toBe(exists);
        });
      },
    );

    it('passes the right props to modal when hasEpicsFeature is true', () => {
      mountComponent({ hasEpicsFeature: true, showNewIssueLink: true });

      expect(findCreateWorkItemModal().exists()).toBe(true);
      expect(findCreateWorkItemModal().props()).toMatchObject({
        isGroup: true,
        workItemTypeName: WORK_ITEM_TYPE_ENUM_EPIC,
      });
    });

    it('passes the `alwaysShowWorkItemTypeSelect` props for project level', () => {
      mountComponent({
        hasEpicsFeature: true,
        showNewIssueLink: true,
        isGroup: false,
        workItemType: WORK_ITEM_TYPE_ENUM_ISSUE,
      });

      expect(findCreateWorkItemModal().exists()).toBe(true);
      expect(findCreateWorkItemModal().props()).toMatchObject({
        isGroup: false,
        alwaysShowWorkItemTypeSelect: true,
        workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE,
      });
    });

    describe('when "workItemCreated" event is emitted', () => {
      it('increments `eeWorkItemUpdateCount` prop on WorkItemsListApp', async () => {
        mountComponent();

        expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(0);

        findCreateWorkItemModal().vm.$emit('workItemCreated');
        await nextTick();

        expect(findWorkItemsListApp().props('eeWorkItemUpdateCount')).toBe(1);
      });
    });
  });

  describe('empty states', () => {
    describe('when hasEpicsFeature=true', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: true });
      });

      it('renders list empty state', () => {
        expect(findListEmptyState().props()).toEqual({
          hasSearch: false,
          isEpic: true,
          isOpenTab: true,
        });
      });

      it('renders page empty state', () => {
        expect(wrapper.findComponent(GlEmptyState).props()).toMatchObject({
          description: 'Track groups of issues that share a theme, across projects and milestones',
          title:
            'Epics let you manage your portfolio of projects more efficiently and with less effort',
        });
      });
    });

    describe('when hasEpicsFeature=false', () => {
      beforeEach(() => {
        mountComponent({ hasEpicsFeature: false });
      });

      it('does not render list empty state', () => {
        expect(findListEmptyState().exists()).toBe(false);
      });

      it('does not render page empty state', () => {
        expect(findPageEmptyState().exists()).toBe(false);
      });
    });
  });

  describe('when bulk editing', () => {
    it('does not show bulk edit toggle by default', () => {
      mountComponent({ hasEpicsFeature: false, canBulkEditEpics: false });

      expect(findBulkEditStartButton().exists()).toBe(false);
      expect(findWorkItemsListApp().props('showBulkEditSidebar')).toBe(false);
    });

    it('does not show bulk edit toggle by if the gql mutation is disabled', () => {
      mountComponent({
        hasEpicsFeature: true,
        canBulkEditEpics: true,
        bulkUpdateMutationEnabled: false,
      });

      expect(findBulkEditStartButton().exists()).toBe(false);
      expect(findWorkItemsListApp().props('showBulkEditSidebar')).toBe(false);
    });

    it('shows the bulk edit toggle when the work item type is epic and the correct features are enabled', () => {
      mountComponent({ hasEpicsFeature: true, canBulkEditEpics: true });

      expect(findBulkEditStartButton().exists()).toBe(true);
    });

    it('opens the bulk update sidebar when the toggle is clicked', async () => {
      mountComponent({ hasEpicsFeature: true, canBulkEditEpics: true });

      await findBulkEditStartButton().vm.$emit('click');

      expect(findWorkItemsListApp().props('showBulkEditSidebar')).toBe(true);
    });

    it('triggers the bulk edit mutation when bulk edit is submitted', async () => {
      await deepMountComponent({ hasEpicsFeature: true, canBulkEditEpics: true });

      const issuableGids = ['gid://gitlab/WorkItem/1', 'gid://gitlab/WorkItem/2'];

      findBulkEditSidebar().vm.$emit('bulk-update', {
        issuable_gids: issuableGids,
        add_label_ids: [1, 2, 3],
        remove_label_ids: [4, 5, 6],
      });

      await waitForPromises();

      expect(workItemBulkUpdateHandler).toHaveBeenCalledWith({
        input: {
          parentId: workItemParentResponse.data.namespace.id,
          ids: issuableGids,
          labelsWidget: {
            addLabelIds: ['gid://gitlab/Label/1', 'gid://gitlab/Label/2', 'gid://gitlab/Label/3'],
            removeLabelIds: [
              'gid://gitlab/Label/4',
              'gid://gitlab/Label/5',
              'gid://gitlab/Label/6',
            ],
          },
        },
      });
    });
  });

  describe('when withTabs is false', () => {
    it('passes the correct props to WorkItemsListApp', () => {
      mountComponent({ props: { withTabs: false } });

      expect(findWorkItemsListApp().props('withTabs')).toBe(false);
    });
  });
});
