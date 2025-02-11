import { safeDump, safeLoad } from 'js-yaml';
import { POLICY_TYPE_COMPONENT_OPTIONS } from 'ee/security_orchestration/components/constants';
import { extractPolicyContent } from 'ee/security_orchestration/components/utils';
import { hasInvalidKey } from '../utils';

/**
 * Construct a policy object expected by the policy editor from a yaml manifest.
 * @param {Object} options
 * @param {String}  options.manifest a security policy in yaml form
 * @returns {Object} security policy
 */

export const fromYaml = ({ manifest }) => {
  try {
    const { securityPoliciesNewYamlFormat = false } = window.gon?.features || {};

    return securityPoliciesNewYamlFormat
      ? extractPolicyContent({
          manifest,
          type: POLICY_TYPE_COMPONENT_OPTIONS.pipelineExecution.urlParameter,
          withType: true,
        })
      : safeLoad(manifest, { json: true });
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

  const contentKeys = ['include'];
  const pipelineConfigStrategies = ['inject_ci', 'override_project_ci'];
  const hasInvalidPipelineConfigStrategy = (strategy) =>
    !pipelineConfigStrategies.includes(strategy);

  if (
    hasInvalidKey(policy?.content || {}, contentKeys) ||
    hasInvalidPipelineConfigStrategy(policy.pipeline_config_strategy)
  ) {
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

export const getInitialPolicy = (defaultPolicy, params = {}) => {
  const {
    type,
    compliance_framework_id: frameworkId,
    compliance_framework_name: frameworkName,
  } = params;
  const [file, project] = params?.path?.split('@') ?? [];

  if (!file || !project || !frameworkId || !frameworkName || !type) {
    return defaultPolicy;
  }

  const newPolicy = Object.assign(fromYaml({ manifest: defaultPolicy }), {
    type,
    pipeline_config_strategy: 'override_project_ci',
    policy_scope: { compliance_frameworks: [{ id: Number(frameworkId) }] },
    content: { include: [{ project, file }] },
    metadata: { compliance_pipeline_migration: true },
  });

  return safeDump(newPolicy);
};
