import {
  ACTION_LISTBOX_ITEMS,
  APPROVER_TYPE_DICT,
  approversOutOfSync,
  actionHasType,
  BOT_MESSAGE_TYPE,
  buildAction,
  createActionFromApprovers,
  REQUIRE_APPROVAL_TYPE,
  WARN_TYPE,
} from 'ee/security_orchestration/components/policy_editor/scan_result/lib/actions';
import { GROUP_TYPE, USER_TYPE, ROLE_TYPE } from 'ee/security_orchestration/constants';

const actionId = 'action_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(actionId));

describe('approversOutOfSync', () => {
  const userApprover = {
    avatarUrl: null,
    id: 1,
    name: null,
    state: null,
    type: USER_TYPE,
    username: 'user name',
    webUrl: null,
  };

  const groupApprover = {
    avatarUrl: null,
    id: 2,
    name: null,
    fullName: null,
    fullPath: 'path/to/group',
    type: GROUP_TYPE,
    webUrl: null,
  };

  const noExistingApprovers = {};
  const existingUserApprover = { user: [userApprover] };
  const existingGroupApprover = { group: [groupApprover] };
  const existingMixedApprovers = { ...existingUserApprover, ...existingGroupApprover };

  describe('with user_approvers_ids only', () => {
    it.each`
      ids                     | approvers               | result
      ${[userApprover.id]}    | ${existingUserApprover} | ${false}
      ${[]}                   | ${noExistingApprovers}  | ${false}
      ${[]}                   | ${existingUserApprover} | ${true}
      ${[userApprover.id]}    | ${noExistingApprovers}  | ${true}
      ${[userApprover.id, 3]} | ${existingUserApprover} | ${true}
      ${[3]}                  | ${noExistingApprovers}  | ${true}
      ${[3]}                  | ${existingUserApprover} | ${true}
    `(
      'return $result when ids and approvers length equal to $ids and $approvers.length',
      ({ ids, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          user_approvers_ids: ids,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
  describe('with user_approvers only', () => {
    it.each`
      usernames                                 | approvers               | result
      ${[userApprover.username]}                | ${existingUserApprover} | ${false}
      ${[]}                                     | ${noExistingApprovers}  | ${false}
      ${[]}                                     | ${existingUserApprover} | ${true}
      ${[userApprover.username]}                | ${noExistingApprovers}  | ${true}
      ${[userApprover.username, 'not present']} | ${existingUserApprover} | ${true}
      ${['not present']}                        | ${noExistingApprovers}  | ${true}
      ${['not present']}                        | ${existingUserApprover} | ${true}
    `(
      'return $result when usernames and approvers length equal to $usernames and $approvers.length',
      ({ usernames, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          user_approvers: usernames,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
  describe('with user_approvers and user_approvers_ids', () => {
    it.each`
      ids                  | usernames                  | approvers               | result
      ${[]}                | ${[userApprover.username]} | ${existingUserApprover} | ${false}
      ${[userApprover.id]} | ${[]}                      | ${existingUserApprover} | ${false}
      ${[]}                | ${[]}                      | ${noExistingApprovers}  | ${false}
      ${[userApprover.id]} | ${[userApprover.username]} | ${existingUserApprover} | ${true}
      ${[userApprover.id]} | ${['not present']}         | ${existingUserApprover} | ${true}
      ${[3]}               | ${[userApprover.username]} | ${existingUserApprover} | ${true}
    `(
      'return $result when ids, usernames and approvers length equal to $ids, $usernames and $approvers.length',
      ({ ids, usernames, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          user_approvers: usernames,
          user_approvers_ids: ids,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
  describe('with group_approvers_ids only', () => {
    it.each`
      ids                      | approvers                | result
      ${[groupApprover.id]}    | ${existingGroupApprover} | ${false}
      ${[]}                    | ${noExistingApprovers}   | ${false}
      ${[]}                    | ${existingGroupApprover} | ${true}
      ${[groupApprover.id]}    | ${noExistingApprovers}   | ${true}
      ${[groupApprover.id, 3]} | ${existingGroupApprover} | ${true}
      ${[3]}                   | ${noExistingApprovers}   | ${true}
      ${[3]}                   | ${existingGroupApprover} | ${true}
    `(
      'return $result when ids and approvers length equal to $ids and $approvers.length',
      ({ ids, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          group_approvers_ids: ids,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
  describe('with user_approvers, user_approvers_ids and group_approvers_ids', () => {
    it.each`
      userApproversIds     | usernames                  | groupApproversIds     | approvers                 | result
      ${[]}                | ${[userApprover.username]} | ${[groupApprover.id]} | ${existingMixedApprovers} | ${false}
      ${[userApprover.id]} | ${[]}                      | ${[groupApprover.id]} | ${existingMixedApprovers} | ${false}
      ${[]}                | ${[]}                      | ${[]}                 | ${noExistingApprovers}    | ${false}
      ${[userApprover.id]} | ${[userApprover.username]} | ${[groupApprover.id]} | ${existingMixedApprovers} | ${true}
      ${[]}                | ${[userApprover.username]} | ${[3]}                | ${existingMixedApprovers} | ${true}
      ${[userApprover.id]} | ${[]}                      | ${[3]}                | ${existingMixedApprovers} | ${true}
      ${[]}                | ${[]}                      | ${[groupApprover.id]} | ${existingGroupApprover}  | ${false}
      ${[userApprover.id]} | ${[]}                      | ${[groupApprover.id]} | ${existingGroupApprover}  | ${true}
      ${[]}                | ${[userApprover.username]} | ${[groupApprover.id]} | ${existingGroupApprover}  | ${true}
      ${[]}                | ${[userApprover.username]} | ${[]}                 | ${existingUserApprover}   | ${false}
      ${[userApprover.id]} | ${[]}                      | ${[]}                 | ${existingUserApprover}   | ${false}
      ${[userApprover.id]} | ${[]}                      | ${[groupApprover.id]} | ${existingUserApprover}   | ${true}
    `(
      'return $result when user_ids, usernames, group_ids and approvers length equal to $userApproversIds, $usernames, $groupApproversIds and $approvers.length',
      ({ userApproversIds, usernames, groupApproversIds, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          user_approvers: usernames,
          user_approvers_ids: userApproversIds,
          group_approvers_ids: groupApproversIds,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
  describe('with group_approvers only', () => {
    it.each`
      fullPath                                   | approvers                | result
      ${[groupApprover.fullPath]}                | ${existingGroupApprover} | ${false}
      ${[]}                                      | ${noExistingApprovers}   | ${false}
      ${[]}                                      | ${existingGroupApprover} | ${true}
      ${[groupApprover.fullPath]}                | ${noExistingApprovers}   | ${true}
      ${[groupApprover.fullPath, 'not present']} | ${existingGroupApprover} | ${true}
      ${['not present']}                         | ${noExistingApprovers}   | ${true}
      ${['not present']}                         | ${existingGroupApprover} | ${true}
    `(
      'return $result when fullPath and approvers length equal to $fullPath and $approvers.length',
      ({ fullPath, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          group_approvers: fullPath,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
  describe('with user_approvers, user_approvers_ids, group_approvers_ids and group_approvers', () => {
    it.each`
      userApproversIds     | usernames                  | groupApproversIds     | groupPaths                  | approvers                 | result
      ${[]}                | ${[userApprover.username]} | ${[groupApprover.id]} | ${[]}                       | ${existingMixedApprovers} | ${false}
      ${[userApprover.id]} | ${[]}                      | ${[groupApprover.id]} | ${[]}                       | ${existingMixedApprovers} | ${false}
      ${[userApprover.id]} | ${[]}                      | ${[]}                 | ${[groupApprover.fullPath]} | ${existingMixedApprovers} | ${false}
      ${[]}                | ${[userApprover.username]} | ${[]}                 | ${[groupApprover.fullPath]} | ${existingMixedApprovers} | ${false}
      ${[]}                | ${[]}                      | ${[]}                 | ${[]}                       | ${noExistingApprovers}    | ${false}
      ${[]}                | ${[userApprover.username]} | ${[3]}                | ${[]}                       | ${existingMixedApprovers} | ${true}
      ${[userApprover.id]} | ${[]}                      | ${[3]}                | ${[]}                       | ${existingMixedApprovers} | ${true}
      ${[userApprover.id]} | ${[]}                      | ${[]}                 | ${['not present']}          | ${existingMixedApprovers} | ${true}
      ${[]}                | ${[userApprover.username]} | ${[]}                 | ${['not present']}          | ${existingMixedApprovers} | ${true}
      ${[userApprover.id]} | ${[]}                      | ${[]}                 | ${[groupApprover.fullPath]} | ${existingGroupApprover}  | ${true}
      ${[]}                | ${[userApprover.username]} | ${[]}                 | ${[groupApprover.fullPath]} | ${existingGroupApprover}  | ${true}
    `(
      'return $result when user_ids, usernames, groupIds, groupPaths and approvers length equal to $userApproversIds, $usernames, $groupApproversIds, $groupPaths and $approvers.length',
      ({ userApproversIds, usernames, groupApproversIds, groupPaths, approvers, result }) => {
        const action = {
          approvals_required: 1,
          type: 'require_approval',
          user_approvers: usernames,
          user_approvers_ids: userApproversIds,
          group_approvers_ids: groupApproversIds,
          group_approvers: groupPaths,
        };
        expect(approversOutOfSync(action, approvers)).toBe(result);
      },
    );
  });
});

describe('actionHasType', () => {
  it.each`
    action                                              | type          | output
    ${{ key: 'value' }}                                 | ${ROLE_TYPE}  | ${false}
    ${{ [APPROVER_TYPE_DICT[ROLE_TYPE][0]]: 'value' }}  | ${USER_TYPE}  | ${false}
    ${{ [APPROVER_TYPE_DICT[USER_TYPE][0]]: 'value' }}  | ${GROUP_TYPE} | ${false}
    ${{ [APPROVER_TYPE_DICT[ROLE_TYPE][0]]: 'value' }}  | ${ROLE_TYPE}  | ${true}
    ${{ [APPROVER_TYPE_DICT[USER_TYPE][0]]: 'value' }}  | ${USER_TYPE}  | ${true}
    ${{ [APPROVER_TYPE_DICT[USER_TYPE][1]]: 'value' }}  | ${USER_TYPE}  | ${true}
    ${{ [APPROVER_TYPE_DICT[GROUP_TYPE][0]]: 'value' }} | ${GROUP_TYPE} | ${true}
    ${{ [APPROVER_TYPE_DICT[GROUP_TYPE][1]]: 'value' }} | ${GROUP_TYPE} | ${true}
  `('returns $output when action is $action and type is $type', ({ action, type, output }) => {
    expect(actionHasType(action, type)).toBe(output);
  });
});

describe('buildAction', () => {
  it('builds an approval action', () => {
    expect(buildAction(REQUIRE_APPROVAL_TYPE)).toEqual({
      approvals_required: 1,
      id: actionId,
      type: REQUIRE_APPROVAL_TYPE,
    });
  });

  it('builds a bot message action', () => {
    expect(buildAction(BOT_MESSAGE_TYPE)).toEqual({
      enabled: true,
      id: actionId,
      type: BOT_MESSAGE_TYPE,
    });
  });

  it('builds a warn action', () => {
    expect(buildAction(WARN_TYPE)).toEqual([
      { approvals_required: 0, id: 'action_0', type: 'require_approval' },
      { enabled: true, id: 'action_0', type: 'send_bot_message' },
    ]);
  });
});

describe('createActionFromApprovers', () => {
  it.each`
    userApprovers                   | groupApprovers
    ${[{ type: USER_TYPE, id: 1 }]} | ${[{ type: GROUP_TYPE, id: 2 }]}
    ${[1]}                          | ${[2]}
  `(
    'creates an action with all approvers $userApprovers and $groupApprovers',
    ({ userApprovers, groupApprovers }) => {
      const action = buildAction(REQUIRE_APPROVAL_TYPE);
      const approvers = {
        [USER_TYPE]: userApprovers,
        [ROLE_TYPE]: ['owner'],
        [GROUP_TYPE]: groupApprovers,
      };
      expect(createActionFromApprovers(action, approvers)).toEqual({
        ...action,
        group_approvers_ids: [2],
        role_approvers: ['owner'],
        user_approvers_ids: [1],
      });
    },
  );
});

describe('ACTION_LISTBOX_ITEMS', () => {
  it('contains two actions', () => {
    expect(ACTION_LISTBOX_ITEMS()).toEqual([
      { text: 'Require Approvers', value: 'require_approval' },
      { text: 'Send bot message', value: 'send_bot_message' },
    ]);
  });

  it('should not include WARN_TYPE when feature flag is off', () => {
    const warnTypeEntry = ACTION_LISTBOX_ITEMS().find((item) => item.value === WARN_TYPE);
    expect(warnTypeEntry).toBeUndefined();
  });

  it('should include WARN_TYPE when feature flag is on', () => {
    window.gon.features = { securityPolicyApprovalWarnMode: true };
    const warnTypeEntry = ACTION_LISTBOX_ITEMS().find((item) => item.value === WARN_TYPE);
    expect(warnTypeEntry).toEqual({ value: WARN_TYPE, text: 'Warn in merge request' });
  });
});
