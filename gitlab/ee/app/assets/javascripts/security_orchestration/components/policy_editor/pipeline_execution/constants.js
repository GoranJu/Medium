import { s__ } from '~/locale';
import { mapToListboxItems } from 'ee/security_orchestration/utils';

export const DEFAULT_PIPELINE_EXECUTION_POLICY = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: ''
`;

export const PIPELINE_EXECUTION_POLICY_INVALID_STRATEGY = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: invalid
content:
  include:
    - project: ''
`;

export const PIPELINE_EXECUTION_POLICY_INVALID_CONTENT = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: invalid
content:
  include_invalid:
    - project: ''
`;

export const DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT = `pipeline_execution_policy:
- name: ''
  description: ''
  enabled: true
  pipeline_config_strategy: inject_ci
  content:
    include:
      - project: ''
`;

export const DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SCOPE = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
policy_scope:
  projects:
    excluding: []
content:
  include:
    - project: ''
`;

export const DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX = `type: pipeline_execution_policy
name: ''
description: ''
enabled: true
pipeline_config_strategy: inject_ci
suffix: on_conflict
content:
  include:
    - project: ''
`;

export const CONDITIONS_LABEL = s__('ScanExecutionPolicy|Conditions');

export const INJECT = 'inject_ci';
export const OVERRIDE = 'override_project_ci';

export const CUSTOM_STRATEGY_OPTIONS = {
  [INJECT]: s__('ScanExecutionPolicy|Inject'),
  [OVERRIDE]: s__('ScanExecutionPolicy|Override'),
};

export const CUSTOM_STRATEGY_OPTIONS_KEYS = Object.keys(CUSTOM_STRATEGY_OPTIONS);
export const CUSTOM_STRATEGY_OPTIONS_LISTBOX_ITEMS = mapToListboxItems(CUSTOM_STRATEGY_OPTIONS);

export const SUFFIX_ON_CONFLICT = 'on_conflict';
export const SUFFIX_NEVER = 'never';

export const SUFFIX_ITEMS = {
  [SUFFIX_ON_CONFLICT]: s__('SecurityOrchestration|On conflict'),
  [SUFFIX_NEVER]: s__('SecurityOrchestration|Never'),
};

export const SUFFIX_LIST_BOX_ITEMS = Object.keys(SUFFIX_ITEMS).map((key) => ({
  value: key,
  text: SUFFIX_ITEMS[key],
}));

export const ACTION_SECTION_DISABLE_ERROR = s__(
  'SecurityOrchestration|The current YAML syntax is invalid so you cannot edit the actions in rule mode. To resolve the issue, switch to YAML mode and fix the syntax.',
);
