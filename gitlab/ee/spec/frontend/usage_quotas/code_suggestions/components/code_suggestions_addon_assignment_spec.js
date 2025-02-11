import { shallowMount } from '@vue/test-utils';
import { GlToggle } from '@gitlab/ui';
import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import Tracking from '~/tracking';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import CodeSuggestionsAddonAssignment from 'ee/usage_quotas/code_suggestions/components/code_suggestions_addon_assignment.vue';
import {
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE,
  DUO_ENTERPRISE_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/saas_add_on_eligible_users.query.graphql';
import userAddOnAssignmentCreateMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_create.mutation.graphql';
import userAddOnAssignmentRemoveMutation from 'ee/usage_quotas/add_on/graphql/user_add_on_assignment_remove.mutation.graphql';
import {
  mockAddOnEligibleUsers,
  mockUserWithAddOnAssignment,
  mockUserWithNoAddOnAssignment,
} from 'ee_jest/usage_quotas/code_suggestions/mock_data';

Vue.use(VueApollo);

jest.mock('~/sentry/sentry_browser_wrapper');

describe('CodeSuggestionsAddonAssignment', () => {
  let wrapper;

  const userIdForAssignment = mockUserWithNoAddOnAssignment.id;
  const userIdForUnassignment = mockUserWithAddOnAssignment.id;

  const addOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/2';
  const duoEnterpriseAddOnPurchaseId = 'gid://gitlab/GitlabSubscriptions::AddOnPurchase/3';

  const codeSuggestionsAddOn = { addOnPurchase: { name: ADD_ON_CODE_SUGGESTIONS } };
  const duoEnterpriseAddOn = { addOnPurchase: { name: ADD_ON_DUO_ENTERPRISE } };

  const addOnPurchase = {
    id: addOnPurchaseId,
    name: ADD_ON_CODE_SUGGESTIONS,
    purchasedQuantity: 3,
    assignedQuantity: 2,
    __typename: 'AddOnPurchase',
  };
  const duoEnterpriseAddOnPurchase = {
    id: duoEnterpriseAddOnPurchaseId,
    name: ADD_ON_DUO_ENTERPRISE,
    purchasedQuantity: 3,
    assignedQuantity: 2,
    __typename: 'AddOnPurchase',
  };

  const addOnEligibleUsersQueryVariables = {
    fullPath: 'namespace/full-path',
    addOnType: ADD_ON_CODE_SUGGESTIONS,
    addOnPurchaseIds: [addOnPurchaseId],
  };
  const duoEnterpriseAddOnEligibleUsersQueryVariables = {
    fullPath: 'namespace/full-path',
    addOnType: ADD_ON_DUO_ENTERPRISE,
    addOnPurchaseIds: [duoEnterpriseAddOnPurchaseId],
  };

  const addOnAssignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase,
    user: {
      id: userIdForAssignment,
      addOnAssignments: {
        nodes: codeSuggestionsAddOn,
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };
  const duoEnterpriseAddOnAssignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase: duoEnterpriseAddOnPurchase,
    user: {
      id: userIdForAssignment,
      addOnAssignments: {
        nodes: duoEnterpriseAddOn,
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };

  const addOnUnassignmentSuccess = {
    clientMutationId: '1',
    errors: [],
    addOnPurchase,
    user: {
      id: userIdForUnassignment,
      addOnAssignments: {
        nodes: [],
        __typename: 'UserAddOnAssignmentConnection',
      },
      __typename: 'AddOnUser',
    },
  };

  const knownAddOnAssignmentError = {
    clientMutationId: '1',
    errors: ['NO_SEATS_AVAILABLE'],
    addOnPurchase: null,
    user: null,
  };
  const unknownAddOnAssignmentError = {
    clientMutationId: '1',
    errors: ['AN_ERROR'],
    addOnPurchase: null,
    user: null,
  };
  const nonStringAddOnAssignmentError = {
    clientMutationId: '1',
    errors: [null],
    addOnPurchase: null,
    user: null,
  };

  const assignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentCreate: addOnAssignmentSuccess },
  });
  const duoEnterpriseAssignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentCreate: duoEnterpriseAddOnAssignmentSuccess },
  });

  const unassignAddOnHandler = jest.fn().mockResolvedValue({
    data: { userAddOnAssignmentRemove: addOnUnassignmentSuccess },
  });

  const createMockApolloProvider = (
    addonAssignmentCreateHandler,
    addOnAssignmentRemoveHandler,
    addOnAssignmentQueryVariables,
  ) => {
    const mockApollo = createMockApollo([
      [userAddOnAssignmentCreateMutation, addonAssignmentCreateHandler],
      [userAddOnAssignmentRemoveMutation, addOnAssignmentRemoveHandler],
    ]);

    // Needed to check if cache update is successful on successful mutation
    mockApollo.clients.defaultClient.cache.writeQuery({
      query: getAddOnEligibleUsers,
      variables: addOnAssignmentQueryVariables,
      data: mockAddOnEligibleUsers.data,
    });

    return mockApollo;
  };

  let mockApolloClient;

  const createComponent = ({
    props = {},
    addonAssignmentCreateHandler = assignAddOnHandler,
    addOnAssignmentRemoveHandler = unassignAddOnHandler,
    addOnAssignmentQueryVariables = addOnEligibleUsersQueryVariables,
  } = {}) => {
    mockApolloClient = createMockApolloProvider(
      addonAssignmentCreateHandler,
      addOnAssignmentRemoveHandler,
      addOnAssignmentQueryVariables,
    );
    wrapper = shallowMount(CodeSuggestionsAddonAssignment, {
      apolloProvider: mockApolloClient,
      propsData: {
        addOnAssignments: [],
        userId: userIdForAssignment,
        addOnPurchaseId,
        ...props,
      },
    });
  };

  const getAddOnAssignmentStatusForUserFromCache = (
    userId,
    variables = addOnEligibleUsersQueryVariables,
  ) => {
    return mockApolloClient.clients.defaultClient.cache
      .readQuery({ query: getAddOnEligibleUsers, variables })
      .namespace.addOnEligibleUsers.nodes.find((node) => node.id === userId).addOnAssignments.nodes;
  };

  const findToggle = () => wrapper.findComponent(GlToggle);

  it('shows correct label on the toggle', () => {
    createComponent();
    expect(findToggle().props('label')).toBe(
      sprintf('%{addOnName} status', { addOnName: CODE_SUGGESTIONS_TITLE }),
    );
  });

  describe('with Duo Enterprise add-on enabled', () => {
    beforeEach(() => {
      return createComponent({ props: { duoTier: DUO_ENTERPRISE } });
    });

    it('shows correct label on the toggle', () => {
      expect(findToggle().props('label')).toBe(
        sprintf('%{addOnName} status', { addOnName: DUO_ENTERPRISE_TITLE }),
      );
    });
  });

  describe.each([
    {
      title: 'when there are assigned add-ons',
      addOnAssignments: [codeSuggestionsAddOn],
      toggleProps: { disabled: false, value: true },
    },
    {
      title: 'when there are no assigned add-ons',
      addOnAssignments: [],
      toggleProps: { disabled: false, value: false },
    },
  ])('$title', ({ addOnAssignments, toggleProps }) => {
    beforeEach(() => {
      createComponent({ props: { addOnAssignments } });
    });

    it('renders addon toggle with appropriate props', () => {
      expect(findToggle().props()).toEqual(expect.objectContaining(toggleProps));
    });
  });

  describe('when assigning a Duo Pro add-on', () => {
    beforeEach(() => {
      jest.spyOn(Tracking, 'event');

      createComponent({
        props: { addOnAssignments: [], userId: userIdForAssignment },
      });
      findToggle().vm.$emit('change', true);
    });

    it('shows loading state for the toggle', () => {
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(getAddOnAssignmentStatusForUserFromCache(userIdForAssignment)).toEqual(
        codeSuggestionsAddOn,
      );
    });

    it('does not show loading state once updated', async () => {
      await waitForPromises();

      expect(findToggle().props('isLoading')).toBe(false);
    });

    it('calls addon assigment mutation with appropriate params', () => {
      expect(assignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId,
        userId: userIdForAssignment,
      });
    });

    it('does not call addon un-assigment mutation', () => {
      expect(unassignAddOnHandler).not.toHaveBeenCalled();
    });

    it('tracks the `enable_gitlab_duo_pro_for_seat` event', async () => {
      await waitForPromises();

      expect(Tracking.event).toHaveBeenCalledWith(
        undefined,
        'enable_gitlab_duo_pro_for_seat',
        expect.any(Object),
      );
    });
  });

  describe('when assigning a Duo Enterprise add-on', () => {
    beforeEach(() => {
      createComponent({
        props: {
          addOnAssignments: [],
          duoTier: DUO_ENTERPRISE,
          userId: userIdForAssignment,
          addOnPurchaseId: duoEnterpriseAddOnPurchaseId,
        },
        addonAssignmentCreateHandler: duoEnterpriseAssignAddOnHandler,
        addOnAssignmentQueryVariables: duoEnterpriseAddOnEligibleUsersQueryVariables,
      });

      findToggle().vm.$emit('change', true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(
        getAddOnAssignmentStatusForUserFromCache(
          userIdForAssignment,
          duoEnterpriseAddOnEligibleUsersQueryVariables,
        ),
      ).toEqual(duoEnterpriseAddOn);
    });

    it('calls addon assigment mutation with appropriate params', () => {
      expect(duoEnterpriseAssignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId: duoEnterpriseAddOnPurchaseId,
        userId: userIdForAssignment,
      });
    });

    it('does not call addon un-assigment mutation', () => {
      expect(unassignAddOnHandler).not.toHaveBeenCalled();
    });
  });

  describe('when error occurs while assigning add-on', () => {
    const addOnAssignments = [];

    it('emits an event with the error code from response for a known error', async () => {
      createComponent({
        props: { addOnAssignments },
        addonAssignmentCreateHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentCreate: knownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['NO_SEATS_AVAILABLE']]);
    });

    it('emits an event with generic error code for a non string error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addonAssignmentCreateHandler: jest.fn().mockResolvedValue({
          data: { userAddOnAssignmentCreate: nonStringAddOnAssignmentError },
        }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['CANNOT_ASSIGN_ADDON']]);
    });

    it('emits an event with generic error code for an unknown error', async () => {
      createComponent({
        props: { addOnAssignments },
        addonAssignmentCreateHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentCreate: unknownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['CANNOT_ASSIGN_ADDON']]);
    });

    it('emits an event with the generic error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addonAssignmentCreateHandler: jest.fn().mockRejectedValue(new Error('An error')),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['CANNOT_ASSIGN_ADDON']]);
    });

    it('captures error on Sentry for generic errors', async () => {
      const error = new Error('An error');
      createComponent({
        props: { addOnAssignments },
        addonAssignmentCreateHandler: jest.fn().mockRejectedValue(error),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(Sentry.captureException).toHaveBeenCalledWith(error);
    });
  });

  describe('when un-assigning an addon', () => {
    beforeEach(() => {
      jest.spyOn(Tracking, 'event');

      createComponent({
        props: { addOnAssignments: [codeSuggestionsAddOn], userId: userIdForUnassignment },
      });
      findToggle().vm.$emit('change', false);
    });

    it('shows loading state for the toggle', () => {
      expect(findToggle().props('isLoading')).toBe(true);
    });

    it('updates the cache with latest add-on assignment status', async () => {
      await waitForPromises();

      expect(getAddOnAssignmentStatusForUserFromCache(userIdForUnassignment)).toEqual([]);
    });

    it('does not show loading state once updated', async () => {
      await waitForPromises();

      expect(findToggle().props('isLoading')).toBe(false);
    });

    it('calls addon un-assigment mutation with appropriate params', () => {
      expect(unassignAddOnHandler).toHaveBeenCalledWith({
        addOnPurchaseId,
        userId: userIdForUnassignment,
      });
    });

    it('does not call addon assigment mutation', () => {
      expect(assignAddOnHandler).not.toHaveBeenCalled();
    });

    it('tracks the `disable_gitlab_duo_pro_for_seat` event', async () => {
      await waitForPromises();

      expect(Tracking.event).toHaveBeenCalledWith(
        undefined,
        'disable_gitlab_duo_pro_for_seat',
        expect.any(Object),
      );
    });
  });

  describe('when error occurs while un-assigning add-on', () => {
    const addOnAssignments = [codeSuggestionsAddOn];

    it('emits an event with the error code from response for a known error', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentRemove: knownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', false);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['NO_SEATS_AVAILABLE']]);
    });

    it('emits an event with generic error code for a non string error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest.fn().mockResolvedValue({
          data: { userAddOnAssignmentRemove: nonStringAddOnAssignmentError },
        }),
      });
      findToggle().vm.$emit('change', true);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['CANNOT_UNASSIGN_ADDON']]);
    });

    it('emits an event with generic error code for an unknown error', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest
          .fn()
          .mockResolvedValue({ data: { userAddOnAssignmentRemove: unknownAddOnAssignmentError } }),
      });
      findToggle().vm.$emit('change', false);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['CANNOT_UNASSIGN_ADDON']]);
    });

    it('emits an event with the generic error code', async () => {
      createComponent({
        props: { addOnAssignments },
        addOnAssignmentRemoveHandler: jest.fn().mockRejectedValue(new Error('An error')),
      });
      findToggle().vm.$emit('change', false);

      await waitForPromises();

      expect(wrapper.emitted('clearError')).toEqual([[]]);
      expect(wrapper.emitted('handleError')).toEqual([['CANNOT_UNASSIGN_ADDON']]);
    });
  });
});
