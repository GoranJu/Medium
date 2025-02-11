import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';

export const DEFAULT_PROVIDE = {
  assignedPolicyProject: null,
  disableSecurityPolicyProject: false,
  disableScanPolicyUpdate: false,
  documentationPath: 'path/to/docs',
  emptyFilterSvgPath: 'path/to/svg',
  emptyListSvgPath: 'path/to/list.svg',
  namespacePath: 'path/to/namespace',
  namespaceType: NAMESPACE_TYPES.PROJECT,
  newPolicyPath: '/-/security/policies/new',
  maxScanExecutionPolicyActions: 5,
};
