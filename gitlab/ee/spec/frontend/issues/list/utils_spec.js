import { getDefaultWorkItemTypes, getTypeTokenOptions } from 'ee/issues/list/utils';
import {
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_ENUM_INCIDENT,
  WORK_ITEM_TYPE_ENUM_ISSUE,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_TASK,
  WORK_ITEM_TYPE_ENUM_TEST_CASE,
} from '~/work_items/constants';

describe('getDefaultWorkItemTypes', () => {
  it('returns default work item types', () => {
    const types = getDefaultWorkItemTypes({
      hasEpicsFeature: true,
      hasOkrsFeature: true,
      hasQualityManagementFeature: true,
    });

    expect(types).toEqual([
      WORK_ITEM_TYPE_ENUM_ISSUE,
      WORK_ITEM_TYPE_ENUM_INCIDENT,
      WORK_ITEM_TYPE_ENUM_TASK,
      WORK_ITEM_TYPE_ENUM_EPIC,
      WORK_ITEM_TYPE_ENUM_KEY_RESULT,
      WORK_ITEM_TYPE_ENUM_OBJECTIVE,
      WORK_ITEM_TYPE_ENUM_TEST_CASE,
    ]);
  });
});

describe('getTypeTokenOptions', () => {
  it('returns options for the Type token', () => {
    const options = getTypeTokenOptions({
      hasEpicsFeature: true,
      hasOkrsFeature: true,
      hasQualityManagementFeature: true,
    });

    expect(options).toEqual([
      { icon: 'issue-type-issue', title: 'Issue', value: 'issue' },
      { icon: 'issue-type-incident', title: 'Incident', value: 'incident' },
      { icon: 'issue-type-task', title: 'Task', value: 'task' },
      { icon: 'epic', title: 'Epic', value: 'epic' },
      { icon: 'issue-type-objective', title: 'Objective', value: 'objective' },
      { icon: 'issue-type-keyresult', title: 'Key Result', value: 'key_result' },
      { icon: 'issue-type-test-case', title: 'Test case', value: 'test_case' },
    ]);
  });
});
