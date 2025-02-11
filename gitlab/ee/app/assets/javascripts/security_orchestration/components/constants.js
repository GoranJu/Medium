import { s__ } from '~/locale';

export const NEW_POLICY_BUTTON_TEXT = s__('SecurityOrchestration|New policy');
export const PIPELINE_EXECUTION_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Pipeline execution',
);
export const VULNERABILITY_MANAGEMENT_POLICY_TYPE_HEADER = s__(
  'SecurityOrchestration|Vulnerability management',
);

export const POLICY_TYPE_COMPONENT_OPTIONS = {
  scanExecution: {
    component: 'scan-execution-policy-editor',
    text: s__('SecurityOrchestration|Scan execution'),
    typeName: 'ScanExecutionPolicy',
    urlParameter: 'scan_execution_policy',
    value: 'scanExecution',
  },
  legacyApproval: {
    component: 'scan-result-policy-editor',
    text: s__('SecurityOrchestration|Merge request approval'),
    typeName: 'ScanResultPolicy',
    urlParameter: 'approval_policy',
    value: 'approval',
  },
  approval: {
    // used by Group.approvalPolicies
    component: 'scan-result-policy-editor',
    text: s__('SecurityOrchestration|Merge request approval'),
    typeName: 'ApprovalPolicy',
    urlParameter: 'approval_policy',
    value: 'approval',
  },
  pipelineExecution: {
    component: 'pipeline-execution-policy-editor',
    text: PIPELINE_EXECUTION_POLICY_TYPE_HEADER,
    typeName: 'PipelineExecutionPolicy',
    urlParameter: 'pipeline_execution_policy',
    value: 'pipeline',
  },
  vulnerabilityManagement: {
    component: 'vulnerability-management-policy-editor',
    text: VULNERABILITY_MANAGEMENT_POLICY_TYPE_HEADER,
    typeName: 'VulnerabilityManagementPolicy',
    urlParameter: 'vulnerability_management_policy',
    value: 'vulnerabilityManagement',
  },
};

export const POLICIES_LIST_CONTAINER_CLASS = '.js-security-policies-container-wrapper';

export const DEFAULT_SKIP_SI_CONFIGURATION = { allowed: true, allowlist: { users: [] } };
