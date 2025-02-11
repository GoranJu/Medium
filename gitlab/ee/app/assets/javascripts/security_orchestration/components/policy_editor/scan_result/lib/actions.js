import { uniqueId, isNumber } from 'lodash';
import { n__, s__ } from '~/locale';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from 'ee/security_orchestration/constants';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const APPROVER_TYPE_DICT = {
  [GROUP_TYPE]: ['group_approvers', 'group_approvers_ids'],
  [ROLE_TYPE]: ['role_approvers'],
  [USER_TYPE]: ['user_approvers', 'user_approvers_ids'],
};

export const ADD_APPROVER_LABEL = s__('SecurityOrchestration|Add new approver');

export const APPROVER_TYPE_LIST_ITEMS = [
  { text: s__('SecurityOrchestration|Roles'), value: ROLE_TYPE },
  { text: s__('SecurityOrchestration|Individual users'), value: USER_TYPE },
  { text: s__('SecurityOrchestration|Groups'), value: GROUP_TYPE },
];

const mapIds = (approvers, namespaceType) =>
  approvers
    .filter((approver) => isNumber(approver) || approver.type === namespaceType)
    .map((item) => (isNumber(item) ? item : item.id));

const userIds = (approvers) => {
  return mapIds(approvers, USER_TYPE);
};

const groupIds = (approvers) => {
  return mapIds(approvers, GROUP_TYPE);
};

export const removeAvailableApproverType = (array, type) =>
  array.filter(({ value }) => value !== type);

/*
  Convert approvers into yaml fields (user_approvers, users_approvers_ids) in relation to action.
*/
export const createActionFromApprovers = ({ id, type, approvals_required }, approvers) => {
  const newAction = { id, type, approvals_required };

  if (approvers[USER_TYPE]) {
    newAction.user_approvers_ids = userIds(approvers[USER_TYPE]);
  }

  if (approvers[GROUP_TYPE]) {
    newAction.group_approvers_ids = groupIds(approvers[GROUP_TYPE]);
  }

  if (approvers[ROLE_TYPE]) {
    newAction.role_approvers = approvers[ROLE_TYPE];
  }

  return newAction;
};

export const actionHasType = (action, type) => {
  return Object.keys(action).some((k) => APPROVER_TYPE_DICT[type].includes(k));
};

/*
  Check if users are present in approvers
*/
const usersOutOfSync = (action, users) => {
  const usersIDs = action?.user_approvers_ids?.some(
    (id) => !users.find((approver) => (approver.id ? approver.id === id : approver === id)),
  );

  const usersNames =
    action?.user_approvers?.some(
      (userName) => !users.find((approver) => approver.username === userName),
    ) || false;
  const userLength =
    (action?.user_approvers?.length || 0) + (action?.user_approvers_ids?.length || 0);

  return usersIDs || usersNames || userLength !== users.length;
};

/*
  Check if groups are present in approvers
*/
const groupsOutOfSync = (action, groups) => {
  const groupsIDs = action?.group_approvers_ids?.some(
    (id) => !groups.find((approver) => (approver.id ? approver.id === id : approver === id)),
  );
  const groupsPaths =
    action?.group_approvers?.some(
      (path) => !groups.find((approver) => approver.fullPath === path),
    ) || false;
  const groupLength =
    (action?.group_approvers?.length || 0) + (action?.group_approvers_ids?.length || 0);

  return groupsIDs || groupsPaths || groupLength !== groups.length;
};

/*
  Check if yaml is out of sync with available approvers
*/
export const approversOutOfSync = (action, { user = [], group = [] }) => {
  return usersOutOfSync(action, user) || groupsOutOfSync(action, group);
};

export const WARN_TEMPLATE = s__(
  'SecurityOrchestration|%{requireStart}Warn users with a bot comment%{requireEnd} and select users as security consultants that developers may contact for support in addressing violations.',
);

export const WARN_TEMPLATE_HELP_TITLE = s__('SecurityOrchestration|Who is a consultant?');

export const WARN_TEMPLATE_HELP_DESCRIPTION = s__(
  'SecurityOrchestration|A consultant will show up in the bot comment and developers should ask them for help if needed.',
);

export const getDefaultHumanizedTemplate = (numOfApproversRequired) => {
  return n__(
    '%{requireStart}Require%{requireEnd} %{approvalsRequired} %{approvalStart}approval%{approvalEnd} from:',
    '%{requireStart}Require%{requireEnd} %{approvalsRequired} %{approvalStart}approvals%{approvalEnd} from:',
    numOfApproversRequired,
  );
};

export const DEFAULT_APPROVER_DROPDOWN_TEXT = s__('SecurityOrchestration|Choose approver type');

export const REQUIRE_APPROVAL_TYPE = 'require_approval';

export const BOT_MESSAGE_TYPE = 'send_bot_message';

export const WARN_TYPE = 'warn';

export const buildApprovalAction = (approvalsRequired = 1) => {
  return {
    type: REQUIRE_APPROVAL_TYPE,
    approvals_required: approvalsRequired,
    id: uniqueId('action_'),
  };
};

export const buildBotMessageAction = () => {
  return { type: BOT_MESSAGE_TYPE, enabled: true, id: uniqueId('action_') };
};

export const buildWarnAction = () => {
  return [buildApprovalAction(0), buildBotMessageAction()];
};

export const buildAction = (type) => {
  switch (type) {
    case REQUIRE_APPROVAL_TYPE:
      return buildApprovalAction();
    case WARN_TYPE:
      return buildWarnAction();
    case BOT_MESSAGE_TYPE:
    default:
      return buildBotMessageAction();
  }
};

export const WARN_TYPE_TEXT = s__('SecurityOrchestration|Warn in merge request');

export const ACTION_OPTIONS = {
  [REQUIRE_APPROVAL_TYPE]: s__('SecurityOrchestration|Require Approvers'),
  [BOT_MESSAGE_TYPE]: s__('SecurityOrchestration|Send bot message'),
};

export const ACTION_LISTBOX_ITEMS = () => {
  const options = {
    ...ACTION_OPTIONS,
    ...(gon.features?.securityPolicyApprovalWarnMode && { [WARN_TYPE]: WARN_TYPE_TEXT }),
  };

  return mapToListboxItems(options);
};

export const DISABLED_BOT_MESSAGE_ACTION = { ...buildAction(BOT_MESSAGE_TYPE), enabled: false };

export const ROLE_PERMISSION_TO_APPROVE_MRS = 'ADMIN_MERGE_REQUEST';
