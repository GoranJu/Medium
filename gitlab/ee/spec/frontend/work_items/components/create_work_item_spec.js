import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { shallowMount } from '@vue/test-utils';
import namespaceWorkItemTypesQueryResponse from 'test_fixtures/graphql/work_items/namespace_work_item_types.query.graphql.json';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CreateWorkItem from '~/work_items/components/create_work_item.vue';
import WorkItemHealthStatus from 'ee/work_items/components/work_item_health_status.vue';
import WorkItemColor from 'ee/work_items/components/work_item_color.vue';
import WorkItemIteration from 'ee/work_items/components/work_item_iteration.vue';
import WorkItemWeight from 'ee/work_items/components/work_item_weight.vue';
import WorkItemRolledupDates from 'ee/work_items/components/work_item_rolledup_dates.vue';
import { WORK_ITEM_TYPE_ENUM_EPIC, WORK_ITEM_TYPE_ENUM_ISSUE } from '~/work_items/constants';
import namespaceWorkItemTypesQuery from '~/work_items/graphql/namespace_work_item_types.query.graphql';
import createWorkItemMutation from '~/work_items/graphql/create_work_item.mutation.graphql';
import workItemByIidQuery from '~/work_items/graphql/work_item_by_iid.query.graphql';
import { resolvers } from '~/graphql_shared/issuable_client';
import {
  createWorkItemMutationResponse,
  createWorkItemQueryResponse,
} from 'jest/work_items/mock_data';

Vue.use(VueApollo);

describe('EE Create work item component', () => {
  let wrapper;
  let mockApollo;

  const createWorkItemSuccessHandler = jest.fn().mockResolvedValue(createWorkItemMutationResponse);
  const workItemQuerySuccessHandler = jest.fn().mockResolvedValue(createWorkItemQueryResponse);
  const namespaceWorkItemTypesHandler = jest
    .fn()
    .mockResolvedValue(namespaceWorkItemTypesQueryResponse);

  const findHealthStatusWidget = () => wrapper.findComponent(WorkItemHealthStatus);
  const findIterationWidget = () => wrapper.findComponent(WorkItemIteration);
  const findWeightWidget = () => wrapper.findComponent(WorkItemWeight);
  const findColorWidget = () => wrapper.findComponent(WorkItemColor);
  const findRolledupDatesWidget = () => wrapper.findComponent(WorkItemRolledupDates);

  const createComponent = ({
    props = {},
    mutationHandler = createWorkItemSuccessHandler,
    workItemTypeName = WORK_ITEM_TYPE_ENUM_EPIC,
  } = {}) => {
    mockApollo = createMockApollo(
      [
        [workItemByIidQuery, workItemQuerySuccessHandler],
        [createWorkItemMutation, mutationHandler],
        [namespaceWorkItemTypesQuery, namespaceWorkItemTypesHandler],
      ],
      resolvers,
    );

    wrapper = shallowMount(CreateWorkItem, {
      apolloProvider: mockApollo,
      propsData: {
        workItemTypeName,
        ...props,
      },
      provide: {
        fullPath: 'full-path',
        groupPath: 'group-path',
        hasIssuableHealthStatusFeature: false,
        hasIterationsFeature: true,
        hasIssueWeightsFeature: true,
      },
    });
  };

  const mockCurrentUser = {
    id: 1,
    name: 'Administrator',
    username: 'root',
    avatar_url: 'avatar/url',
  };

  beforeEach(() => {
    gon.current_user_id = mockCurrentUser.id;
    gon.current_user_fullname = mockCurrentUser.name;
    gon.current_username = mockCurrentUser.username;
    gon.current_user_avatar_url = mockCurrentUser.avatar_url;
  });

  describe('Create work item widgets for Epic work item type', () => {
    beforeEach(async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_EPIC });
      await waitForPromises();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item color widget', () => {
      expect(findColorWidget().exists()).toBe(true);
    });

    it('renders the work item rolled up dates widget', () => {
      expect(findRolledupDatesWidget().exists()).toBe(true);
    });
  });

  describe('Create work item widgets for Issue work item type', () => {
    beforeEach(async () => {
      createComponent({ workItemTypeName: WORK_ITEM_TYPE_ENUM_ISSUE });
      await waitForPromises();
    });

    it('renders the work item health status widget', () => {
      expect(findHealthStatusWidget().exists()).toBe(true);
    });

    it('renders the work item iteration widget', () => {
      expect(findIterationWidget().exists()).toBe(true);
    });

    it('renders the work item weight widget', () => {
      expect(findWeightWidget().exists()).toBe(true);
    });
  });
});
