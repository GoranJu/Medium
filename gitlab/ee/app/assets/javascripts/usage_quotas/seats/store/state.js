export default ({
  namespaceId = null,
  maxFreeNamespaceSeats = null,
  enforcementFreeUserCapEnabled = false,
} = {}) => ({
  initialized: false,
  isLoadingBillableMembers: false,
  isLoadingGitlabSubscription: false,
  isChangingMembershipState: false,
  isRemovingBillableMember: false,
  removedBillableMemberId: null,
  hasError: false,
  namespaceId,
  members: [],
  total: null,
  planCode: null,
  planName: null,
  page: null,
  perPage: null,
  billableMemberToRemove: null,
  userDetails: {},
  search: null,
  sort: 'last_activity_on_desc',
  seatsInSubscription: 0,
  seatsInUse: null,
  maxSeatsUsed: null,
  seatsOwed: null,
  maxFreeNamespaceSeats,
  hasLimitedFreePlan: enforcementFreeUserCapEnabled,
  hasReachedFreePlanLimit: null,
  activeTrial: false,
  subscriptionEndDate: null,
  subscriptionStartDate: null,
});
