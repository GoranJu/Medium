# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class SecurityPolicy < ApplicationRecord
      include EachBatch

      self.table_name = 'compliance_framework_security_policies'

      belongs_to :policy_configuration, class_name: 'Security::OrchestrationPolicyConfiguration'
      belongs_to :framework, class_name: 'ComplianceManagement::Framework'

      validates :framework, uniqueness: { scope: [:policy_configuration_id, :policy_index] }

      scope :for_framework, ->(framework) { where(framework: framework) }
      scope :for_policy_configuration, ->(policy_configuration) { where(policy_configuration: policy_configuration) }

      has_many :security_policy_requirements,
        class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement',
        foreign_key: :compliance_framework_security_policy_id,
        inverse_of: :compliance_framework_security_policy

      has_many :compliance_requirements,
        through: :security_policy_requirements,
        inverse_of: :compliance_framework_security_policies

      class << self
        def delete_for_policy_configuration(policy_configuration)
          for_policy_configuration(policy_configuration).each_batch(order_hint: :updated_at) do |batch|
            batch.delete_all
          end
        end

        def relink(configuration, framework_policy_attrs)
          transaction do
            delete_for_policy_configuration(configuration)

            insert_all(framework_policy_attrs) if framework_policy_attrs.any?
          end
        end
      end
    end
  end
end
