import {
  DEFAULT_PIPELINE_EXECUTION_POLICY,
  DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX,
  DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT,
  PIPELINE_EXECUTION_POLICY_INVALID_STRATEGY,
  PIPELINE_EXECUTION_POLICY_INVALID_CONTENT,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import {
  createPolicyObject,
  fromYaml,
  getInitialPolicy,
  validatePolicy,
} from 'ee/security_orchestration/components/policy_editor/pipeline_execution/utils';
import {
  customYaml,
  customYamlObject,
  customYamlObjectFromUrlParams,
  customYamlUrlParams,
  invalidStrategyManifest,
  invalidYaml,
  mockPipelineExecutionObject,
  mockWithSuffixPipelineExecutionObject,
} from 'ee_jest/security_orchestration/mocks/mock_pipeline_execution_policy_data';
import {
  policyBodyToYaml,
  policyToYaml,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';

describe('fromYaml', () => {
  it.each`
    title                                                                     | input                                                          | output
    ${'returns the policy object for a supported manifest'}                   | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }}             | ${mockPipelineExecutionObject}
    ${'returns the policy object for a supported manifest with suffix'}       | ${{ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY_WITH_SUFFIX }} | ${mockWithSuffixPipelineExecutionObject}
    ${'returns the policy object for a policy with an unsupported attribute'} | ${{ manifest: customYaml }}                                    | ${customYamlObject}
    ${'returns empty object for a policy with an invalid yaml'}               | ${{ manifest: invalidYaml }}                                   | ${{}}
  `('$title', ({ input, output }) => {
    expect(fromYaml(input)).toStrictEqual(output);
  });
});

describe('validatePolicy', () => {
  it.each`
    title                                                                  | input                                                                 | output
    ${'returns empty object when there are no errors'}                     | ${fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY })}          | ${{}}
    ${'returns error objects when there are actions and rules violations'} | ${fromYaml({ manifest: customYaml })}                                 | ${{ actions: true }}
    ${'returns error objects when there are invalid pipeline strategy'}    | ${fromYaml({ manifest: PIPELINE_EXECUTION_POLICY_INVALID_STRATEGY })} | ${{ actions: true }}
    ${'returns error objects when there is invalid content'}               | ${fromYaml({ manifest: PIPELINE_EXECUTION_POLICY_INVALID_CONTENT })}  | ${{ actions: true }}
  `('$title', ({ input, output }) => {
    expect(validatePolicy(input)).toStrictEqual(output);
  });
});

describe('createPolicyObject', () => {
  const errorPolicy = {
    content: { include: [{ file: '.pipeline-execution.yml', project: 'GitLab.org/GitLab' }] },
    description: 'triggers all protected branches except main',
    enabled: true,
    name: 'Ci config file',
    pipeline_config_strategy: 'this_is_wrong',
  };

  it.each`
    title                                                                            | input                                           | output                                                                                     | securityPoliciesNewYamlFormat
    ${'returns the policy object and no errors for a supported manifest'}            | ${DEFAULT_PIPELINE_EXECUTION_POLICY}            | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }), parsingError: {} }} | ${false}
    ${'returns the policy object and no errors for a supported manifest new format'} | ${DEFAULT_PIPELINE_EXECUTION_POLICY_NEW_FORMAT} | ${{ policy: fromYaml({ manifest: DEFAULT_PIPELINE_EXECUTION_POLICY }), parsingError: {} }} | ${true}
    ${'returns the error policy object and the error for an unsupported manifest'}   | ${customYaml}                                   | ${{ policy: { variable: true }, parsingError: { actions: true } }}                         | ${false}
    ${'returns the error policy object and the error for an invalid strategy name'}  | ${invalidStrategyManifest}                      | ${{ policy: errorPolicy, parsingError: { actions: true } }}                                | ${false}
  `('$title', ({ input, output, securityPoliciesNewYamlFormat }) => {
    window.gon.features = { securityPoliciesNewYamlFormat };
    expect(createPolicyObject(input)).toStrictEqual(output);
  });
});

describe('policyToYaml', () => {
  it('returns policy object as yaml', () => {
    expect(
      policyToYaml(customYamlObject, POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter),
    ).toBe(customYaml);
  });
});

describe('toYaml', () => {
  it('returns policy object as yaml', () => {
    expect(policyBodyToYaml(customYamlObject)).toBe(customYaml);
  });
});

describe('getInitialPolicy', () => {
  it('updates initialPolicy with passed params if all params are present', () => {
    const expectedYaml = customYamlObjectFromUrlParams(customYamlUrlParams);
    expect(getInitialPolicy(customYaml, customYamlUrlParams)).toBe(expectedYaml);
  });

  it.each(Object.keys(customYamlUrlParams).map((key) => [key]))(
    'ignores other url params if %s is missing',
    (key) => {
      const params = { ...customYamlUrlParams };
      delete params[key];
      expect(getInitialPolicy(customYaml, params)).toBe(customYaml);
    },
  );
});
