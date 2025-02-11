# frozen_string_literal: true

module Security
  class ApprovalPolicyRule < ApplicationRecord
    include PolicyRule
    include EachBatch

    self.table_name = 'approval_policy_rules'

    enum type: { scan_finding: 0, license_finding: 1, any_merge_request: 2 }, _prefix: true

    belongs_to :security_policy, class_name: 'Security::Policy', inverse_of: :approval_policy_rules

    has_many :approval_policy_rule_project_links, class_name: 'Security::ApprovalPolicyRuleProjectLink'
    has_many :projects, through: :approval_policy_rule_project_links
    has_many :software_license_policies
    has_one :approval_project_rule
    has_many :approval_merge_request_rules
    has_many :violations, class_name: 'Security::ScanResultPolicyViolation'

    validates :typed_content, json_schema: { filename: "approval_policy_rule_content" }

    def self.by_policy_rule_index(policy_configuration, policy_index:, rule_index:)
      joins(:security_policy).find_by(
        rule_index: rule_index,
        security_policy: {
          security_orchestration_policy_configuration_id: policy_configuration.id,
          policy_index: policy_index
        }
      )
    end
  end
end
