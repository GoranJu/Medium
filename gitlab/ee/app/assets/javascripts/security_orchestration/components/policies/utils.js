import {
  BREAKING_CHANGES_POPOVER_CONTENTS,
  POLICY_SOURCE_OPTIONS,
  POLICY_TYPE_FILTER_OPTIONS,
} from 'ee/security_orchestration/components/policies/constants';
import { fromYaml } from 'ee/security_orchestration/components/policy_editor/scan_execution/lib';
import { sprintf } from '~/locale';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';

/**
 * @param {Object} allowedValues
 * @param value
 * @param lowerCase
 * @returns {boolean}
 */
const validateFilter = (allowedValues, value, lowerCase = false) => {
  if (typeof value !== 'string') return false;

  return Object.values(allowedValues)
    .map((option) => (lowerCase ? option.value?.toLowerCase() : option.value))
    .includes(lowerCase ? value?.toLowerCase() : value);
};

/**
 * Check validity of value against allowed list
 * @param value
 * @returns {boolean}
 */
export const validateTypeFilter = (value) => {
  return validateFilter(POLICY_TYPE_FILTER_OPTIONS, value, true);
};

/**
 * Check validity of value against allowed list
 * @param value
 * @returns {boolean}
 */
export const validateSourceFilter = (value) => validateFilter(POLICY_SOURCE_OPTIONS, value, true);

/**
 * Conversion between lower case url params and policies
 * uppercase constants
 * @param type
 * @returns {string|undefined|string}
 */
export const extractTypeParameter = (type) => {
  // necessary for bookmarks of /-/security/policies?type=scan_result
  const updatedType = type === 'scan_result' ? 'approval' : type;
  return validateTypeFilter(updatedType)
    ? updatedType?.toUpperCase()
    : POLICY_TYPE_FILTER_OPTIONS.ALL.value;
};

/**
 * Conversion between lower case url params and policies
 * uppercase constants
 * @param source
 * @returns {string|undefined|string}
 */
export const extractSourceParameter = (source) =>
  validateSourceFilter(source) ? source?.toUpperCase() : POLICY_SOURCE_OPTIONS.ALL.value;

/**
 * Return true if number of scan execution policy actions exceeds allowed amount
 * @param {string} policyType
 * @param {string} yaml
 * @param {number} maxScanExecutionPolicyActions
 * @returns {boolean}
 */
export const exceedsActionLimit = ({ policyType, yaml, maxScanExecutionPolicyActions } = {}) => {
  if (policyType === POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.text) {
    const policy = fromYaml({ manifest: yaml });

    const { actions = [] } = policy;
    return actions.length > maxScanExecutionPolicyActions;
  }

  return false;
};

/**
 * Build violation list based on conditions
 * @param {string} policyType
 * @param {Array} deprecatedProperties
 * @param {string} yaml
 * @param {number} maxScanExecutionPolicyActions
 * @returns {string[]}
 */
export const buildPolicyViolationList = ({
  policyType,
  deprecatedProperties = [],
  yaml = '',
  maxScanExecutionPolicyActions,
}) => {
  const violationList = [];

  const hasDeprecatedProperties =
    Boolean(BREAKING_CHANGES_POPOVER_CONTENTS[policyType]) && deprecatedProperties?.length > 0;

  if (hasDeprecatedProperties) {
    violationList.push({
      content: sprintf(BREAKING_CHANGES_POPOVER_CONTENTS[policyType].content, {
        deprecatedProperties: deprecatedProperties.join(', '),
      }),
      link: BREAKING_CHANGES_POPOVER_CONTENTS[policyType].link,
    });
  }

  if (exceedsActionLimit({ policyType, yaml, maxScanExecutionPolicyActions })) {
    violationList.push({
      content: sprintf(BREAKING_CHANGES_POPOVER_CONTENTS.exceedingAction.content, {
        maxScanExecutionPolicyActions,
      }),
      link: BREAKING_CHANGES_POPOVER_CONTENTS.exceedingAction.link,
    });
  }

  return violationList;
};
