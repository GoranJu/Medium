import { POLICY_SCOPE_MOCK } from 'ee_jest/security_orchestration/mocks/mock_apollo';
import { fromYaml } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';

/**
 * Naming convention for mocks:
 * mock policy yaml => name ends in `Manifest`
 * mock parsed yaml => name ends in `Object`
 * mock policy for list/drawer => name ends in `Policy`
 *
 * If you have the same policy in multiple forms (e.g. mock yaml and mock parsed yaml that should
 * match), please name them similarly (e.g. fooBarManifest and fooBarObject)
 * and keep them near each other.
 */

export const customYaml = `variable: true
`;

export const invalidYaml = 'variable: true:';

export const customYamlObject = { variable: true };

export const mockPipelineExecutionObject = {
  content: { include: [{ project: '' }] },
  description: '',
  enabled: true,
  name: '',
  pipeline_config_strategy: 'inject_ci',
  type: 'pipeline_execution_policy',
};

export const mockWithScopePipelineExecutionObject = {
  ...mockPipelineExecutionObject,
  policy_scope: { projects: { excluding: [] } },
};

export const mockWithSuffixPipelineExecutionObject = {
  ...mockPipelineExecutionObject,
  suffix: 'on_conflict',
};

export const mockInvalidPipelineExecutionObject = {
  ...mockPipelineExecutionObject,
  pipeline_config_strategy: 'invalid_option',
};

export const customYamlUrlParams = {
  type: 'pipeline_execution_policy',
  compliance_framework_id: 1,
  compliance_framework_name: 'Foo',
  path: 'foo@bar',
};

export const customYamlObjectFromUrlParams = (params) => `${customYaml.trim()}
type: ${params.type}
pipeline_config_strategy: override_project_ci
policy_scope:
  compliance_frameworks:
    - id: ${params.compliance_framework_id}
content:
  include:
    - project: bar
      file: foo
metadata:
  compliance_pipeline_migration: true
`;

export const mockWithoutRefPipelineExecutionManifest = `type: pipeline_execution_policy
name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: inject_ci
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
`;

export const mockWithoutRefPipelineExecutionObject = fromYaml({
  manifest: mockWithoutRefPipelineExecutionManifest,
});

export const invalidStrategyManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: this_is_wrong
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
`;

export const skipCiConfigurationManifest = `name: Ci config file
description: triggers all protected branches except main
enabled: true
pipeline_config_strategy: inject_ci
skip_ci:
  allowed: true
content:
  include:
    - project: GitLab.org/GitLab
      file: .pipeline-execution.yml
`;

export const mockPipelineExecutionManifest = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
pipeline_config_strategy: inject_ci
enabled: false
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
`;

export const mockPipelineExecutionWithConfigurationManifest = `type: pipeline_execution_policy
name: Include external file
description: This policy enforces pipeline execution with configuration from external file
pipeline_config_strategy: inject_ci
enabled: false
skip_ci:
   allowed: true
content:
   include:
     - project: gitlab-policies/js6
       ref: main
       file: pipeline_execution_jobs.yml
`;

export const mockPipelineScanExecutionObject = {
  type: 'pipeline_execution_policy',
  name: 'Include external file',
  description: 'This policy enforces pipeline execution with configuration from external file',
  enabled: false,
  rules: [],
  actions: [
    {
      content: 'include:\n project: gitlab-policies/js9 id: 27 ref: main file: README.md',
    },
  ],
};

export const mockProjectPipelineExecutionPolicy = {
  __typename: 'PipelineExecutionPolicy',
  name: `${mockPipelineScanExecutionObject.name}-project`,
  updatedAt: new Date('2021-06-07T00:00:00.000Z'),
  yaml: mockPipelineExecutionManifest,
  editPath: '/policies/policy-name/edit?type="pipeline_execution_policy"',
  policyBlobFilePath: '/path/to/project/-/blob/main/pipeline_execution_jobs.yml',
  enabled: true,
  ...POLICY_SCOPE_MOCK,
  source: {
    __typename: 'ProjectSecurityPolicySource',
    project: {
      fullPath: 'project/path',
    },
  },
};

export const mockProjectPipelineExecutionWithConfigurationPolicy = {
  ...mockProjectPipelineExecutionPolicy,
  yaml: mockPipelineExecutionWithConfigurationManifest,
};

export const mockGroupPipelineExecutionPolicy = {
  ...mockProjectPipelineExecutionPolicy,
  enabled: false,
  source: {
    __typename: 'GroupSecurityPolicySource',
    inherited: true,
    namespace: {
      __typename: 'Namespace',
      id: '1',
      fullPath: 'parent-group-path',
      name: 'parent-group-name',
    },
  },
};

export const mockPipelineExecutionPoliciesResponse = [
  mockProjectPipelineExecutionPolicy,
  mockGroupPipelineExecutionPolicy,
];
