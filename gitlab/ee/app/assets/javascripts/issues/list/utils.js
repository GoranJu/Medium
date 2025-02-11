/* eslint-disable import/export */
import {
  getDefaultWorkItemTypes as getDefaultWorkItemTypesCE,
  getTypeTokenOptions as getTypeTokenOptionsCE,
} from '~/issues/list/utils';
import { __, s__ } from '~/locale';
import {
  WORK_ITEM_TYPE_ENUM_EPIC,
  WORK_ITEM_TYPE_ENUM_KEY_RESULT,
  WORK_ITEM_TYPE_ENUM_OBJECTIVE,
  WORK_ITEM_TYPE_ENUM_TEST_CASE,
} from '~/work_items/constants';

export * from '~/issues/list/utils';

/**
 * Get the types of work items that should be displayed on issues lists.
 * This should be consistent with `Issue::TYPES_FOR_LIST` in the backend.
 *
 * @returns {Array<string>}
 * */
export const getDefaultWorkItemTypes = ({
  hasEpicsFeature,
  hasOkrsFeature,
  hasQualityManagementFeature,
}) => {
  const types = getDefaultWorkItemTypesCE();
  if (hasEpicsFeature) {
    types.push(WORK_ITEM_TYPE_ENUM_EPIC);
  }
  if (hasOkrsFeature) {
    types.push(WORK_ITEM_TYPE_ENUM_KEY_RESULT, WORK_ITEM_TYPE_ENUM_OBJECTIVE);
  }
  if (hasQualityManagementFeature) {
    types.push(WORK_ITEM_TYPE_ENUM_TEST_CASE);
  }
  return types;
};

export const getTypeTokenOptions = ({
  hasEpicsFeature,
  hasOkrsFeature,
  hasQualityManagementFeature,
}) => {
  const options = getTypeTokenOptionsCE();
  if (hasEpicsFeature) {
    options.push({
      icon: 'epic',
      title: __('Epic'),
      value: 'epic',
    });
  }
  if (hasOkrsFeature) {
    options.push(
      { icon: 'issue-type-objective', title: s__('WorkItem|Objective'), value: 'objective' },
      { icon: 'issue-type-keyresult', title: s__('WorkItem|Key Result'), value: 'key_result' },
    );
  }
  if (hasQualityManagementFeature) {
    options.push({
      icon: 'issue-type-test-case',
      title: s__('WorkItem|Test case'),
      value: 'test_case',
    });
  }
  return options;
};
