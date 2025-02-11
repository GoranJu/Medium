import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_USER } from '~/graphql_shared/constants';
import { convertObjectPropsToCamelCase } from '~/lib/utils/common_utils';
import { defaultClient } from 'ee/vue_shared/security_configuration/graphql/provider';
import { POLICY_TYPE_COMPONENT_OPTIONS } from './components/constants';
import { GROUP_TYPE, ROLE_TYPE, USER_TYPE } from './constants';

/**
 * Get a property from a policy's typename
 * @param {String} typeName policy's typename from GraphQL
 * @param {String} field
 * @returns {String|null} policy property if available
 */
export const getPolicyType = (typeName = '', field = 'value') => {
  return Object.values(POLICY_TYPE_COMPONENT_OPTIONS).find(
    (component) => component.typeName === typeName,
  )?.[field];
};

/**
 * Separate existing approvers by type
 * @param {Array} existingApprovers all approvers
 * @returns {Object} approvers separated by type
 */
export const decomposeApprovers = (existingApprovers) => {
  return existingApprovers.map((approvers) => {
    const output = {};

    const { users = [], groups = [], roles = [] } = approvers;

    const hasUsers = users.length > 0;
    const hasGroups = groups.length > 0;
    const hasRoles = roles.length > 0;

    if (hasRoles) {
      output[ROLE_TYPE] = approvers.roles || [];
    }

    if (hasUsers) {
      output[USER_TYPE] =
        approvers.users
          .map((user) => ({
            ...user,
            type: USER_TYPE,
            value: convertToGraphQLId(TYPENAME_USER, user.id),
          }))
          .map(convertObjectPropsToCamelCase) || [];
    }

    if (hasGroups) {
      output[GROUP_TYPE] =
        approvers.groups
          .map((group) => ({
            ...group,
            type: GROUP_TYPE,
            value: convertToGraphQLId(TYPENAME_GROUP, group.id),
          }))
          .map(convertObjectPropsToCamelCase) || [];
    }

    return output;
  });
};

/**
 * Removes initial line dashes from a policy YAML that is received from the API, which
 * is not required for the user.
 * @param {String} manifest the policy from the API request
 * @returns {String} the policy without the initial dashes or the initial string
 */
export const removeUnnecessaryDashes = (manifest) => {
  return manifest.replace('---\n', '');
};

/**
 * Create GraphQL Client for security policies
 */
export const gqClient = defaultClient;

/**
 * Transforms a key-value mapping into an array of objects suitable for use with
 * GlCollapsibleListbox component.
 *
 * @param {Object} textMap - An object where keys represent values and values represent display text.
 * @returns {Array<Object>} An array of objects, each containing 'value' and 'text' properties.
 *
 * @example
 * const mapping = { 'key1': 'Text 1', 'key2': 'Text 2' };
 * const listBoxItems = mapToListboxItems(mapping);
 * // returns: [{ value: 'key1', text: 'Text 1' }, { value: 'key2', text: 'Text 2' }]
 */

export const mapToListboxItems = (textMap) =>
  Object.entries(textMap).map(([value, text]) => ({
    value,
    text,
  }));
