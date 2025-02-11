export { createPolicyObject, fromYaml } from './from_yaml';
export * from './to_yaml';
export * from './rules';
export * from './cron';
export * from './actions';

export const DEFAULT_SCAN_EXECUTION_POLICY = `type: scan_execution_policy
name: ''
description: ''
enabled: true
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE = `type: scan_execution_policy
name: ''
description: ''
enabled: true
policy_scope:
  projects:
    excluding: []
rules:
  - type: pipeline
    branches:
      - '*'
actions:
  - scan: secret_detection
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_NEW_FORMAT = `scan_execution_policy:
- name: ''
  description: ''
  enabled: true
  rules:
  - type: pipeline
    branches:
      - '*'
  actions:
    - scan: secret_detection
`;

export const DEFAULT_SCAN_EXECUTION_POLICY_WITH_SCOPE_NEW_FORMAT = `scan_execution_policy:
- name: ''
  description: ''
  enabled: true
  policy_scope:
    projects:
      excluding: []
  rules:
    - type: pipeline
      branches:
        - '*'
  actions:
    - scan: secret_detection
`;
