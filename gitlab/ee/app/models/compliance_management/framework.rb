# frozen_string_literal: true

module ComplianceManagement
  class Framework < ApplicationRecord
    include StripAttribute
    include Gitlab::SQL::Pattern

    self.table_name = 'compliance_management_frameworks'

    strip_attributes! :name, :color

    belongs_to :namespace
    has_many :project_settings, class_name: 'ComplianceManagement::ComplianceFramework::ProjectSettings'
    has_many :projects, through: :project_settings

    has_many :compliance_framework_security_policies,
      class_name: 'ComplianceManagement::ComplianceFramework::SecurityPolicy'

    has_many :security_orchestration_policy_configurations,
      -> { distinct },
      class_name: 'Security::OrchestrationPolicyConfiguration',
      through: :compliance_framework_security_policies,
      source: :policy_configuration

    has_many :compliance_requirements, class_name: 'ComplianceManagement::ComplianceFramework::ComplianceRequirement'

    validates :namespace, presence: true
    validates :name, presence: true, length: { maximum: 255 }
    validates :description, presence: true, length: { maximum: 255 }
    validates :color, color: true, allow_blank: false, length: { maximum: 10 }
    validates :namespace_id, uniqueness: { scope: :name }
    validates :pipeline_configuration_full_path, length: { maximum: 255 }

    # Remove this validation once support for user namespaces is added.
    # https://gitlab.com/gitlab-org/gitlab/-/issues/358423
    validate :namespace_is_root_level_group

    scope :with_projects, ->(project_ids) {
      includes(:projects)
      .where(projects: { id: project_ids })
      .ordered_by_addition_time_and_pipeline_existence
    }
    scope :with_namespaces, ->(namespace_ids) { includes(:namespace).where(namespaces: { id: namespace_ids }) }
    scope :ordered_by_addition_time_and_pipeline_existence, -> {
      left_joins(:project_settings)
        .order(
          Arel.sql('CASE WHEN pipeline_configuration_full_path IS NULL THEN 1 ELSE 0 END'),
          Arel.sql('project_compliance_framework_settings.created_at ASC NULLS LAST')
        )
    }

    def self.search(query)
      query.present? ? fuzzy_search(query, [:name], use_minimum_char_limit: true) : all
    end

    def filename = "compliance-framework-#{name.parameterize}-#{id}"

    private

    def namespace_is_root_level_group
      return unless namespace

      errors.add(:namespace, 'must be a group, user namespaces are not supported.') unless namespace.group_namespace?
      errors.add(:namespace, 'must be a root group.') if namespace.has_parent?
    end
  end
end
