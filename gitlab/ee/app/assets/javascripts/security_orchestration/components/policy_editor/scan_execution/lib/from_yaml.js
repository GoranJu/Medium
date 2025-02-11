import { safeLoad } from 'js-yaml';
import {
  DEFAULT_TEMPLATE,
  LATEST_TEMPLATE,
} from 'ee/security_orchestration/components/policy_editor/scan_execution/action/scan_filters/constants';
import { extractPolicyContent } from 'ee/security_orchestration/components/utils';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { addIdsToPolicy, hasConflictingKeys, hasInvalidCron } from '../../utils';
import {
  BRANCH_TYPE_KEY,
  RULE_MODE_SCANNERS,
  VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS,
} from '../../constants';

/**
 * Check if any rule has invalid branch type
 * @param rules list of rules with either branches or branch_type property
 * @returns {Boolean}
 */
const hasInvalidBranchType = (rules) => {
  if (!rules) return false;

  return rules.some(
    (rule) =>
      BRANCH_TYPE_KEY in rule &&
      !VALID_SCAN_EXECUTION_BRANCH_TYPE_OPTIONS.includes(rule.branch_type),
  );
};

/**
 * Check if any action has invalid template type
 * @param {Array} actions
 * @returns {Boolean}
 */
const hasInvalidTemplate = (actions = []) => {
  return actions.some(({ template }) => {
    return (template || template === '') && ![DEFAULT_TEMPLATE, LATEST_TEMPLATE].includes(template);
  });
};

/**
 * Checks if any action has invalid scanner type
 * @param {Array} actions
 * @returns {Boolean} if all inputted scanners are in the available scanners dictionary
 */
export const hasInvalidScanners = (actions = []) => {
  if (!actions.length) return false;

  const availableScanners = Object.keys(RULE_MODE_SCANNERS);

  const configuredScanners = actions.map((action) => action.scan);
  return configuredScanners.some((scanner) => !availableScanners.includes(scanner));
};

/**
 * Construct a policy object expected by the policy editor from a yaml manifest.
 * @param {Object} options
 * @param {String}  options.manifest a security policy in yaml form
 * @returns {Object} security policy as JS object
 */
export const fromYaml = ({ manifest }) => {
  const { securityPoliciesNewYamlFormat = false } = window.gon?.features || {};

  try {
    const payload = securityPoliciesNewYamlFormat
      ? extractPolicyContent({
          manifest,
          type: POLICY_TYPE_COMPONENT_OPTIONS.scanExecution.urlParameter,
          withType: true,
        })
      : safeLoad(manifest, { json: true });

    return addIdsToPolicy(payload);
  } catch {
    /**
     * Catch parsing error of safeLoad
     */
    return {};
  }
};

/**
 * Validate policy actions and rules keys
 * @param policy
 * @returns {Object} errors object. If empty, policy is valid.
 */
export const validatePolicy = (policy) => {
  const error = {};
  if (
    hasConflictingKeys(policy.rules) ||
    hasInvalidBranchType(policy.rules) ||
    hasInvalidCron(policy.rules)
  ) {
    error.rules = true;
  }

  if (hasInvalidTemplate(policy.actions) || hasInvalidScanners(policy.actions)) {
    error.actions = true;
  }

  return error;
};

/**
 * Converts a security policy from yaml to an object
 * @param {String} manifest a security policy in yaml form
 * @returns {Object} security policy object and any errors
 */
export const createPolicyObject = (manifest) => {
  const policy = fromYaml({ manifest });
  const parsingError = validatePolicy(policy);

  return { policy, parsingError };
};
