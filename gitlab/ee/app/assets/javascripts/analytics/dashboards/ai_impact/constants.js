import { pick } from 'lodash';
import { s__ } from '~/locale';
import {
  FLOW_METRICS,
  DORA_METRICS,
  VULNERABILITY_METRICS,
  AI_METRICS,
  UNITS,
} from '~/analytics/shared/constants';

import { helpPagePath } from '~/helpers/help_page_helper';
import { TABLE_METRICS as VSD_TABLE_METRICS } from '../constants';

export const SUPPORTED_FLOW_METRICS = [FLOW_METRICS.CYCLE_TIME, FLOW_METRICS.LEAD_TIME];

export const SUPPORTED_DORA_METRICS = [
  DORA_METRICS.DEPLOYMENT_FREQUENCY,
  DORA_METRICS.CHANGE_FAILURE_RATE,
];

export const SUPPORTED_VULNERABILITY_METRICS = [VULNERABILITY_METRICS.CRITICAL];

export const SUPPORTED_AI_METRICS = [
  AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
  AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE,
  AI_METRICS.DUO_CHAT_USAGE_RATE,
];
export const HIDE_METRIC_DRILL_DOWN = [
  AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE,
  AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE,
  AI_METRICS.DUO_CHAT_USAGE_RATE,
];

// The AI impact metrics supported for over time tiles
export const AI_IMPACT_OVER_TIME_METRICS = {
  [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Code Suggestions usage'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE]: {
    label: s__('AiImpactAnalytics|Code Suggestions acceptance rate'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.DUO_CHAT_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Duo Chat: Unique users'),
    units: UNITS.PERCENT,
  },
  [AI_METRICS.DUO_USAGE_RATE]: {
    label: s__('AiImpactAnalytics|Duo seats: Assigned and used'),
    units: UNITS.PERCENT,
  },
};

export const AI_IMPACT_TABLE_METRICS = {
  ...pick(VSD_TABLE_METRICS, [
    ...SUPPORTED_FLOW_METRICS,
    ...SUPPORTED_DORA_METRICS,
    ...SUPPORTED_VULNERABILITY_METRICS,
  ]),
  ...pick(AI_IMPACT_OVER_TIME_METRICS, SUPPORTED_AI_METRICS),
};

export const AI_IMPACT_OVER_TIME_METRICS_TOOLTIPS = {
  [AI_METRICS.CODE_SUGGESTIONS_USAGE_RATE]: {
    description: s__(
      'AiImpactAnalytics|Monthly user engagement with AI Code Suggestions. Percentage ratio calculated as monthly unique Code Suggestions users / total monthly unique code contributors in the last 30 days. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/project/repository/code_suggestions/_index', {
      anchor: 'use-code-suggestions',
    }),
  },
  [AI_METRICS.CODE_SUGGESTIONS_ACCEPTANCE_RATE]: {
    description: s__(
      'AiImpactAnalytics|%{codeSuggestionsAcceptedCount} out of %{codeSuggestionsShownCount} code suggestions were accepted in the last 30 days. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/project/repository/code_suggestions/_index', {
      anchor: 'use-code-suggestions',
    }),
  },
  [AI_METRICS.DUO_CHAT_USAGE_RATE]: {
    description: s__(
      'AiImpactAnalytics|%{duoChatContributorsCount} out of %{duoAssignedUsersCount} GitLab Duo users interacted with Duo Chat in the last 30 days. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('user/gitlab_duo_chat/_index'),
  },
  [AI_METRICS.DUO_USAGE_RATE]: {
    description: s__(
      'AiImpactAnalytics|%{duoUsedCount} out of %{duoAssignedUsersCount} GitLab Duo assigned seats used at least one AI feature in the last 30 days. %{linkStart}Learn more%{linkEnd}.',
    ),
    descriptionLink: helpPagePath('subscriptions/subscription-add-ons', {
      anchor: 'assign-gitlab-duo-seats',
    }),
  },
};
