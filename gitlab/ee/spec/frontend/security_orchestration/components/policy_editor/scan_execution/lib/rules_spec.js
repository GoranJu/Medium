import {
  buildDefaultPipeLineRule,
  buildDefaultScheduleRule,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/lib/rules';

const ruleId = 'rule_0';
jest.mock('lodash/uniqueId', () => jest.fn().mockReturnValue(ruleId));

describe('buildDefaultPipeLineRule', () => {
  it('builds a pipeline rule', () => {
    expect(buildDefaultPipeLineRule()).toEqual({
      branches: ['*'],
      id: ruleId,
      type: 'pipeline',
    });
  });
});

describe('buildDefaultScheduleRule', () => {
  it('builds a schedule rule', () => {
    expect(buildDefaultScheduleRule()).toEqual({
      branches: [],
      cadence: '0 0 * * *',
      id: ruleId,
      type: 'schedule',
    });
  });
});
