import { CUSTOM_STRATEGY_OPTIONS_KEYS } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/constants';
import { validateStrategyValues } from 'ee/security_orchestration/components/policy_editor/pipeline_execution/action/utils';

describe('validateStrategyValues', () => {
  it.each`
    input                              | expected
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[0]} | ${true}
    ${CUSTOM_STRATEGY_OPTIONS_KEYS[1]} | ${true}
    ${'other string'}                  | ${false}
  `('validates correctly for $input', ({ input, expected }) => {
    expect(validateStrategyValues(input)).toBe(expected);
  });
});
