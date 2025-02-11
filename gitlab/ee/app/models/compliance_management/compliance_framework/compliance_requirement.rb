# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ComplianceRequirement < ApplicationRecord
      self.table_name = 'compliance_requirements'

      MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT = 50

      CONTROL_EXPRESSION_SCHEMA_PATH = 'ee/app/validators/json_schemas/compliance_requirement_expression.json'
      CONTROL_EXPRESSION_SCHEMA = JSONSchemer.schema(Rails.root.join(CONTROL_EXPRESSION_SCHEMA_PATH))

      enum requirement_type: { internal: 0 }

      belongs_to :framework, class_name: 'ComplianceManagement::Framework', optional: false
      belongs_to :namespace, optional: false

      validates_presence_of :framework, :namespace_id, :name, :description
      validates :name, uniqueness: { scope: :framework_id }
      validate :requirements_count_per_framework
      validates :name, :description, length: { maximum: 255 }
      validates :control_expression, length: { maximum: 2048 }
      validate :validate_internal_expression

      has_many :security_policy_requirements,
        class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicyRequirement'

      has_many :compliance_framework_security_policies,
        through: :security_policy_requirements,
        inverse_of: :compliance_requirements

      has_many :compliance_requirements_controls,
        class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl'
      has_many :project_control_compliance_statuses,
        class_name: 'ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus'

      private

      def requirements_count_per_framework
        if framework.nil? || framework.compliance_requirements.count < MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT
          return
        end

        errors.add(:framework, format(_("cannot have more than %{count} requirements"),
          count: MAX_COMPLIANCE_REQUIREMENTS_PER_FRAMEWORK_COUNT))
      end

      def validate_internal_expression
        return unless requirement_type == 'internal'
        return if control_expression.blank?

        expression_schema_errors = CONTROL_EXPRESSION_SCHEMA.validate(Gitlab::Json.parse(control_expression)).to_a
        return if expression_schema_errors.blank?

        expression_schema_errors.each do |error|
          errors.add(:expression, JSONSchemer::Errors.pretty(error))
        end
      rescue JSON::ParserError
        errors.add(:expression, _('should be a valid json object.'))
      end
    end
  end
end
