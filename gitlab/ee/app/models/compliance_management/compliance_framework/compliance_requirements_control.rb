# frozen_string_literal: true

module ComplianceManagement
  module ComplianceFramework
    class ComplianceRequirementsControl < ApplicationRecord
      self.table_name = 'compliance_requirements_controls'
      attr_encrypted :secret_token,
        mode: :per_attribute_iv,
        key: Settings.attr_encrypted_db_key_base_32,
        algorithm: 'aes-256-gcm',
        encode: false,
        encode_iv: false

      MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT = 5
      CONTROL_EXPRESSION_SCHEMA_PATH = 'ee/app/validators/json_schemas/compliance_requirements_control_expression.json'
      CONTROL_EXPRESSION_SCHEMA = JSONSchemer.schema(Rails.root.join(CONTROL_EXPRESSION_SCHEMA_PATH))

      belongs_to :compliance_requirement,
        class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirement', optional: false
      belongs_to :namespace

      has_many :project_control_compliance_statuses,
        class_name: 'ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus'

      enum name: {
        scanner_sast_running: 0,
        minimum_approvals_required_2: 1,
        merge_request_prevent_author_approval: 2,
        merge_request_prevent_committers_approval: 3,
        project_visibility_not_internal: 4,
        default_branch_protected: 5,
        external_control: 10000
      }

      enum control_type: {
        internal: 0,
        external: 1
      }

      validates_presence_of :name, :control_type, :namespace, :compliance_requirement
      validates_presence_of :expression, if: :internal?

      validates :expression, length: { maximum: 255 }
      validate :validate_internal_expression, if: :internal?
      validate :controls_count_per_requirement

      validates :external_url, presence: true, addressable_url: true,
        uniqueness: { scope: :compliance_requirement_id }, if: :external?
      validates :name, uniqueness: { scope: :compliance_requirement_id }, if: :internal?
      validates :secret_token, presence: true, if: :external?

      def expression_as_hash
        ::Gitlab::Json.parse(expression)
      rescue JSON::ParserError
        errors.add(:expression, _('should be a valid json object.'))

        nil
      end

      private

      def controls_count_per_requirement
        if compliance_requirement.nil? || compliance_requirement.compliance_requirements_controls.count <
            MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT
          return
        end

        errors.add(:compliance_requirement, format(_("cannot have more than %{count} controls"),
          count: MAX_COMPLIANCE_CONTROLS_PER_REQUIREMENT_COUNT))
      end

      def validate_internal_expression
        return if expression.blank?

        hashed_expression = expression_as_hash
        return if errors[:expression].any?

        expression_schema_errors = CONTROL_EXPRESSION_SCHEMA.validate(hashed_expression).to_a
        return if expression_schema_errors.blank?

        expression_schema_errors.each do |error|
          errors.add(:expression, JSONSchemer::Errors.pretty(error))
        end
      end
    end
  end
end
