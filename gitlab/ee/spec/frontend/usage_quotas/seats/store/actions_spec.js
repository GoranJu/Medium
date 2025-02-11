import * as GroupsApi from 'ee/api/groups_api';
import Api from 'ee/api';
import * as actions from 'ee/usage_quotas/seats/store/actions';
import * as types from 'ee/usage_quotas/seats/store/mutation_types';
import createState from 'ee/usage_quotas/seats/store/state';
import {
  mockDataSeats,
  mockMemberDetails,
  mockUserSubscription,
} from 'ee_jest/usage_quotas/seats/mock_data';
import testAction from 'helpers/vuex_action_helper';
import { createAlert, VARIANT_SUCCESS } from '~/alert';
import Tracking from '~/tracking';

jest.mock('ee/api/groups_api');
jest.mock('ee/api');
jest.mock('~/alert');
jest.mock('~/tracking');

describe('Usage Quotas Seats actions', () => {
  /** @type {ReturnType<createState>} */
  let state;

  beforeEach(() => {
    state = createState();
  });

  describe('fetchInitialData', () => {
    it('triggers initializing actions', async () => {
      state.initialized = false;

      await testAction({
        action: actions.fetchInitialData,
        payload: null,
        state,
        expectedMutations: [{ type: types.SET_STATE_INITIALIZED }],
        expectedActions: [
          { type: 'fetchBillableMembersList' },
          { type: 'fetchGitlabSubscription' },
        ],
      });
    });

    it('will not initialize twice', async () => {
      state.initialized = true;

      await testAction({
        action: actions.fetchInitialData,
        payload: null,
        state,
        expectedMutations: [],
        expectedActions: [],
      });
    });
  });

  describe('fetchBillableMembersList', () => {
    const payload = {
      page: 5,
      search: 'search string',
      sort: 'last_activity_on_desc',
    };

    beforeEach(() => {
      state = Object.assign(state, {
        namespaceId: 1,
        page: 5,
        search: 'search string',
        sort: 'last_activity_on_desc',
        hasLimitedFreePlan: false,
        previewFreeUserCap: false,
        hasNoSubscription: false,
      });

      GroupsApi.fetchBillableGroupMembersList.mockResolvedValue({
        data: mockDataSeats.data,
        headers: mockDataSeats.headers,
      });
    });

    it('passes correct arguments to Api call', async () => {
      await testAction({
        action: actions.fetchBillableMembersList,
        payload,
        state,
        expectedMutations: expect.anything(),
        expectedActions: expect.anything(),
      });

      expect(GroupsApi.fetchBillableGroupMembersList).toHaveBeenCalledWith(
        state.namespaceId,
        expect.objectContaining(payload),
      );
    });

    describe('on success', () => {
      it('should dispatch the request and success actions', () => {
        return testAction({
          action: actions.fetchBillableMembersList,
          state,
          expectedActions: [
            {
              type: 'receiveBillableMembersListSuccess',
              payload: mockDataSeats,
            },
          ],
          expectedMutations: [{ type: types.REQUEST_BILLABLE_MEMBERS }],
        });
      });
    });

    describe('on error', () => {
      it('should dispatch the request and error actions', () => {
        GroupsApi.fetchBillableGroupMembersList.mockRejectedValue();

        return testAction({
          action: actions.fetchBillableMembersList,
          state,
          expectedActions: [{ type: 'receiveBillableMembersListError' }],
          expectedMutations: [{ type: types.REQUEST_BILLABLE_MEMBERS }],
        });
      });
    });
  });

  describe('receiveBillableMembersListSuccess', () => {
    it('should commit the success mutation', () => {
      return testAction({
        action: actions.receiveBillableMembersListSuccess,
        payload: mockDataSeats,
        state,
        expectedMutations: [
          { type: types.RECEIVE_BILLABLE_MEMBERS_SUCCESS, payload: mockDataSeats },
        ],
      });
    });
  });

  describe('receiveBillableMembersListError', () => {
    it('should commit the error mutation', async () => {
      await testAction({
        action: actions.receiveBillableMembersListError,
        state,
        expectedMutations: [{ type: types.RECEIVE_BILLABLE_MEMBERS_ERROR }],
      });

      expect(createAlert).toHaveBeenCalled();
    });
  });

  describe('fetchGitlabSubscription', () => {
    beforeEach(() => {
      state.namespaceId = 1;
      Api.userSubscription.mockResolvedValue({ data: mockUserSubscription });
    });

    it('passes correct arguments to Api call', async () => {
      await testAction({
        action: actions.fetchGitlabSubscription,
        state,
        expectedMutations: expect.anything(),
        expectedActions: expect.anything(),
      });

      expect(Api.userSubscription).toHaveBeenCalledWith(state.namespaceId);
    });

    describe('on success', () => {
      it('should dispatch the request and success actions', () => {
        return testAction({
          action: actions.fetchGitlabSubscription,
          state,
          expectedActions: [
            {
              type: 'receiveGitlabSubscriptionSuccess',
              payload: mockUserSubscription,
            },
          ],
          expectedMutations: [{ type: types.REQUEST_GITLAB_SUBSCRIPTION }],
        });
      });
    });

    describe('on error', () => {
      it('should dispatch the request and error actions', () => {
        Api.userSubscription.mockRejectedValue();

        return testAction({
          action: actions.fetchGitlabSubscription,
          state,
          expectedActions: [{ type: 'receiveGitlabSubscriptionError' }],
          expectedMutations: [{ type: types.REQUEST_GITLAB_SUBSCRIPTION }],
        });
      });
    });
  });

  describe('receiveGitlabSubscriptionSuccess', () => {
    it('should commit the success mutation', () => {
      return testAction({
        action: actions.receiveGitlabSubscriptionSuccess,
        payload: mockDataSeats,
        state,
        expectedMutations: [
          { type: types.RECEIVE_GITLAB_SUBSCRIPTION_SUCCESS, payload: mockDataSeats },
        ],
      });
    });
  });

  describe('receiveGitlabSubscriptionError', () => {
    it('should commit the error mutation', async () => {
      await testAction({
        action: actions.receiveGitlabSubscriptionError,
        state,
        expectedMutations: [{ type: types.RECEIVE_GITLAB_SUBSCRIPTION_ERROR }],
      });

      expect(createAlert).toHaveBeenCalled();
    });
  });

  describe('setBillableMemberToRemove', () => {
    it('should commit the set member mutation', async () => {
      const member = { id: 'test' };

      await testAction({
        action: actions.setBillableMemberToRemove,
        payload: member,
        state,
        expectedMutations: [{ type: types.SET_BILLABLE_MEMBER_TO_REMOVE, payload: member }],
      });
    });
  });

  describe('removeBillableMember', () => {
    beforeEach(() => {
      state = {
        namespaceId: 1,
        billableMemberToRemove: {
          id: 2,
        },
      };
    });

    describe('on success', () => {
      it('dispatches the removeBillableMemberSuccess action', async () => {
        GroupsApi.removeBillableMemberFromGroup.mockResolvedValue();

        await testAction({
          action: actions.removeBillableMember,
          state,
          expectedActions: [{ type: 'removeBillableMemberSuccess', payload: 2 }],
          expectedMutations: [{ type: types.REMOVE_BILLABLE_MEMBER }],
        });

        expect(GroupsApi.removeBillableMemberFromGroup).toHaveBeenCalledWith(
          state.namespaceId,
          state.billableMemberToRemove.id,
        );
      });
    });

    describe('on error', () => {
      it('dispatches the removeBillableMemberError action', async () => {
        GroupsApi.removeBillableMemberFromGroup.mockRejectedValue();

        await testAction({
          action: actions.removeBillableMember,
          state,
          expectedActions: [{ type: 'removeBillableMemberError' }],
          expectedMutations: [{ type: types.REMOVE_BILLABLE_MEMBER }],
        });

        expect(GroupsApi.removeBillableMemberFromGroup).toHaveBeenCalled();
      });
    });
  });

  describe('removeBillableMemberSuccess', () => {
    const memberId = 13;

    it('dispatches fetchBillableMembersList', async () => {
      await testAction({
        action: actions.removeBillableMemberSuccess,
        payload: memberId,
        state,
        expectedActions: [
          { type: 'fetchBillableMembersList' },
          { type: 'fetchGitlabSubscription' },
        ],

        expectedMutations: [{ type: types.REMOVE_BILLABLE_MEMBER_SUCCESS, payload: { memberId } }],
      });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'User was successfully removed',
        variant: VARIANT_SUCCESS,
      });
    });
  });

  describe('removeBillableMemberError', () => {
    it('commits remove member error', async () => {
      await testAction({
        action: actions.removeBillableMemberError,
        state,
        expectedMutations: [{ type: types.REMOVE_BILLABLE_MEMBER_ERROR }],
      });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while removing a billable member.',
      });
    });
  });

  describe('fetchBillableMemberDetails', () => {
    const member = mockDataSeats.data[0];

    beforeAll(() => {
      GroupsApi.fetchBillableGroupMemberMemberships.mockResolvedValue({ data: mockMemberDetails });
      GroupsApi.fetchBillableGroupMemberIndirectMemberships.mockResolvedValue({
        data: mockMemberDetails,
      });
    });

    it('commits fetchBillableMemberDetails', async () => {
      await testAction({
        action: actions.fetchBillableMemberDetails,
        payload: member.id,
        state,
        expectedMutations: [
          { type: types.FETCH_BILLABLE_MEMBER_DETAILS, payload: { memberId: member.id } },
          {
            type: types.FETCH_BILLABLE_MEMBER_DETAILS_SUCCESS,
            payload: {
              memberId: member.id,
              memberships: mockMemberDetails,
              hasIndirectMembership: false,
            },
          },
        ],
      });
    });

    it('calls fetchBillableGroupMemberMemberships and fetchBillableGroupMemberIndirectMemberships API', async () => {
      await testAction({
        action: actions.fetchBillableMemberDetails,
        payload: member.id,
        state,
        expectedMutations: [
          { type: types.FETCH_BILLABLE_MEMBER_DETAILS, payload: { memberId: member.id } },
          {
            type: types.FETCH_BILLABLE_MEMBER_DETAILS_SUCCESS,
            payload: {
              memberId: member.id,
              memberships: mockMemberDetails,
              hasIndirectMembership: false,
            },
          },
        ],
      });

      expect(GroupsApi.fetchBillableGroupMemberMemberships).toHaveBeenCalledWith(null, 2);
      expect(GroupsApi.fetchBillableGroupMemberIndirectMemberships).toHaveBeenCalledWith(null, 2);
    });

    it('calls fetchBillableGroupMemberMemberships and fetchBillableGroupMemberIndirectMemberships API only once', async () => {
      await testAction({
        action: actions.fetchBillableMemberDetails,
        payload: member.id,
        state,
        expectedMutations: [
          { type: types.FETCH_BILLABLE_MEMBER_DETAILS, payload: { memberId: member.id } },
          {
            type: types.FETCH_BILLABLE_MEMBER_DETAILS_SUCCESS,
            payload: {
              memberId: member.id,
              memberships: mockMemberDetails,
              hasIndirectMembership: false,
            },
          },
        ],
      });

      state.userDetails[member.id] = { items: mockMemberDetails, isLoading: false };

      await testAction({
        action: actions.fetchBillableMemberDetails,
        payload: member.id,
        state,
        expectedMutations: [
          {
            type: types.FETCH_BILLABLE_MEMBER_DETAILS_SUCCESS,
            payload: {
              memberId: member.id,
              memberships: mockMemberDetails,
            },
          },
        ],
      });

      expect(GroupsApi.fetchBillableGroupMemberMemberships).toHaveBeenCalledTimes(1);
      expect(GroupsApi.fetchBillableGroupMemberIndirectMemberships).toHaveBeenCalledTimes(1);
    });

    describe('committing members and indirectMembership', () => {
      const mockIndirectMemberDetails = { ...mockMemberDetails, hasIndirectMembership: true };

      describe.each`
        membershipApiRes       | indirectMembershipApiRes       | memberships                    | hasIndirectMembership
        ${[]}                  | ${[]}                          | ${[]}                          | ${false}
        ${[mockMemberDetails]} | ${[]}                          | ${[mockMemberDetails]}         | ${false}
        ${[]}                  | ${[mockIndirectMemberDetails]} | ${[mockIndirectMemberDetails]} | ${true}
        ${[mockMemberDetails]} | ${[mockIndirectMemberDetails]} | ${[mockMemberDetails]}         | ${false}
      `(
        'fetchBillableMemberDetails',
        ({ membershipApiRes, indirectMembershipApiRes, memberships, hasIndirectMembership }) => {
          it(`commits the correct mutation when response ${
            membershipApiRes.length ? 'does' : 'does not'
          } include membership and ${
            indirectMembershipApiRes.length ? 'does' : 'does not'
          } include indirect membership`, () => {
            GroupsApi.fetchBillableGroupMemberMemberships.mockResolvedValue({
              data: membershipApiRes,
            });
            GroupsApi.fetchBillableGroupMemberIndirectMemberships.mockResolvedValue({
              data: indirectMembershipApiRes,
            });

            return testAction({
              action: actions.fetchBillableMemberDetails,
              payload: member.id,
              state,
              expectedMutations: [
                { type: types.FETCH_BILLABLE_MEMBER_DETAILS, payload: { memberId: member.id } },
                {
                  type: types.FETCH_BILLABLE_MEMBER_DETAILS_SUCCESS,
                  payload: {
                    memberId: member.id,
                    memberships,
                    hasIndirectMembership,
                  },
                },
              ],
            });
          });
        },
      );
    });

    describe('on API error', () => {
      it('dispatches fetchBillableMemberDetailsError', async () => {
        GroupsApi.fetchBillableGroupMemberMemberships.mockRejectedValue();

        await testAction({
          action: actions.fetchBillableMemberDetails,
          payload: member.id,
          state,
          expectedMutations: [
            { type: types.FETCH_BILLABLE_MEMBER_DETAILS, payload: { memberId: member.id } },
          ],
          expectedActions: [{ type: 'fetchBillableMemberDetailsError', payload: member.id }],
        });
      });
    });
  });

  describe('fetchBillableMemberDetailsError', () => {
    const memberId = 42;

    it('commits fetch billable member details error', async () => {
      await testAction({
        action: actions.fetchBillableMemberDetailsError,
        payload: memberId,
        state,
        expectedMutations: [
          { type: types.FETCH_BILLABLE_MEMBER_DETAILS_ERROR, payload: { memberId } },
        ],
      });
    });

    it('calls createAlert', async () => {
      await testAction({
        action: actions.fetchBillableMemberDetailsError,
        payload: memberId,
        state,
        expectedMutations: [
          { type: types.FETCH_BILLABLE_MEMBER_DETAILS_ERROR, payload: { memberId } },
        ],
      });

      expect(createAlert).toHaveBeenCalledWith({
        message: 'An error occurred while getting a billable member details.',
      });
    });
  });

  describe('setSortOptions', () => {
    const sortOption = 'recent_sign_in';

    it('sends snowplow tracking event', async () => {
      await testAction({
        action: actions.setSortOption,
        payload: sortOption,
        state,
        expectedMutations: [{ type: types.SET_SORT_OPTION, payload: sortOption }],
        expectedActions: [
          {
            type: 'fetchBillableMembersList',
          },
        ],
      });

      expect(Tracking.event).toHaveBeenCalledWith('usage_quota_seats', 'click', {
        label: 'billable_members_table_sort_selection',
        property: 'recent_sign_in',
      });
    });
  });

  describe('setSearchQuery', () => {
    const searchQuery = 'one';

    it('dispatches fetchBillableMembersList', async () => {
      await testAction({
        action: actions.setSearchQuery,
        payload: searchQuery,
        state,
        expectedMutations: [
          { type: types.SET_CURRENT_PAGE, payload: 1 },
          { type: types.SET_SEARCH_QUERY, payload: searchQuery },
        ],
        expectedActions: [{ type: 'fetchBillableMembersList' }],
      });
    });
  });

  describe('setCurrentPage', () => {
    const page = 11;

    it('dispatches fetchBillableMembersList', async () => {
      await testAction({
        action: actions.setCurrentPage,
        payload: page,
        state,
        expectedMutations: [{ type: types.SET_CURRENT_PAGE, payload: page }],
        expectedActions: [{ type: 'fetchBillableMembersList' }],
      });
    });
  });
});
