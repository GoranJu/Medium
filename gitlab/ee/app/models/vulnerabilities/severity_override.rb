# frozen_string_literal: true

module Vulnerabilities
  class SeverityOverride < Gitlab::Database::SecApplicationRecord
    self.table_name = 'vulnerability_severity_overrides'

    belongs_to :vulnerability, class_name: 'Vulnerability', inverse_of: :severity_overrides
    belongs_to :author, class_name: 'User', inverse_of: :vulnerability_severity_overrides
    belongs_to :project, optional: false
    validates :vulnerability, :project, :original_severity, :new_severity, presence: true
    validates :author, presence: true, on: :create
    validates :original_severity, presence: true,
      inclusion: { in: ::Enums::Vulnerability.severity_levels.keys }
    validates :new_severity, presence: true,
      inclusion: { in: ::Enums::Vulnerability.severity_levels.keys }
    validate :original_and_new_severity_differ?

    enum original_severity: ::Enums::Vulnerability.severity_levels, _prefix: true
    enum new_severity: ::Enums::Vulnerability.severity_levels, _prefix: true

    scope :with_author, -> { includes(:author) }

    private

    def original_and_new_severity_differ?
      return unless original_severity.present? && new_severity.present?
      return if original_severity != new_severity

      errors.add(:new_severity, "must not be the same as original severity")
    end
  end
end
