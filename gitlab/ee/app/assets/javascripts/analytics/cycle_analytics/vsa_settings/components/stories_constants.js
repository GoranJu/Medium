/* eslint-disable @gitlab/require-i18n-strings */

export const defaultGroupLabels = [
  {
    id: 1,
    title: 'in-dev',
    color: '#4018cc',
    project_id: null,
    text_color: '#FFFFFF',
  },
  {
    id: 2,
    title: 'in-review',
    color: '#48b29d',
    project_id: null,
    text_color: '#FFFFFF',
  },
  {
    id: 3,
    title: 'done',
    color: '#4c20e8',
    project_id: null,
    text_color: '#FFFFFF',
  },
];

export const defaultStageConfig = [
  {
    custom: false,
    relativePosition: 1,
    startEventIdentifier: 'issue_created',
    endEventIdentifier: 'issue_stage_end',
    name: 'Issue',
  },
  {
    custom: false,
    relativePosition: 2,
    startEventIdentifier: 'plan_stage_start',
    endEventIdentifier: 'issue_first_mentioned_in_commit',
    name: 'Plan',
  },
  {
    custom: false,
    relativePosition: 3,
    startEventIdentifier: 'code_stage_start',
    endEventIdentifier: 'merge_request_created',
    name: 'Code',
  },
];

export const formEvents = [
  {
    name: 'Issue closed',
    identifier: 'issue_closed',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: ['issue_last_edited', 'issue_label_added', 'issue_label_removed'],
  },
  {
    name: 'Issue created',
    identifier: 'issue_created',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'issue_deployed_to_production',
      'issue_closed',
      'issue_first_added_to_board',
      'issue_first_associated_with_milestone',
      'issue_first_mentioned_in_commit',
      'issue_last_edited',
      'issue_label_added',
      'issue_label_removed',
      'issue_first_assigned_at',
      'issue_first_added_to_iteration',
    ],
  },
  {
    name: 'Issue first mentioned in a commit',
    identifier: 'issue_first_mentioned_in_commit',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'issue_closed',
      'issue_first_associated_with_milestone',
      'issue_first_added_to_board',
      'issue_last_edited',
      'issue_label_added',
      'issue_label_removed',
      'issue_first_assigned_at',
      'issue_first_added_to_iteration',
    ],
  },
  {
    name: 'Issue label was added',
    identifier: 'issue_label_added',
    type: 'label',
    canBeStartEvent: true,
    allowedEndEvents: [
      'issue_label_added',
      'issue_label_removed',
      'issue_closed',
      'issue_first_assigned_at',
      'issue_first_added_to_iteration',
    ],
  },
  {
    name: 'Issue label was removed',
    identifier: 'issue_label_removed',
    type: 'label',
    canBeStartEvent: true,
    allowedEndEvents: ['issue_closed', 'issue_first_assigned_at', 'issue_first_added_to_iteration'],
  },
  {
    name: 'Merge request merged',
    identifier: 'merge_request_merged',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'merge_request_first_deployed_to_production',
      'merge_request_closed',
      'merge_request_first_deployed_to_production',
      'merge_request_last_edited',
      'merge_request_label_added',
      'merge_request_label_removed',
      'merge_request_first_commit_at',
    ],
  },
  {
    name: 'Merge request created',
    identifier: 'merge_request_created',
    type: 'simple',
    canBeStartEvent: true,
    allowedEndEvents: [
      'merge_request_merged',
      'merge_request_closed',
      'merge_request_first_deployed_to_production',
      'merge_request_last_build_started',
      'merge_request_last_build_finished',
      'merge_request_last_edited',
      'merge_request_label_added',
      'merge_request_label_removed',
      'merge_request_first_assigned_at',
    ],
  },
];

export const selectedValueStream = { id: 16, name: 'Cool value stream', isCustom: true };

const [startEventLabel, endEventLabel] = defaultGroupLabels;
export const customStage = {
  hidden: false,
  legend: 'Custom legend',
  description: 'Time before an issue gets scheduled',
  id: 341,
  title: 'Custom stage 1',
  name: 'Custom stage 1',
  startEventIdentifier: 'issue_label_added',
  endEventIdentifier: 'issue_label_removed',
  startEventLabel,
  endEventLabel,
  startEventLabelId: startEventLabel.id,
  endEventLabelId: endEventLabel.id,
  isDefault: false,
  custom: true,
};

export const selectedValueStreamStages = ({ hideStages = false, addCustomStage = false } = {}) => [
  ...(addCustomStage ? [customStage] : []),
  ...defaultStageConfig.map(({ custom, name }) => ({ custom, name, hidden: hideStages })),
];

export const formSubmissionErrors = {
  name: ['has already been taken'],
  stages: [
    {
      name: ['has already been taken'],
    },
  ],
};
