# frozen_string_literal: true

module Vulnerabilities
  class Archive < Gitlab::Database::SecApplicationRecord
    self.table_name = 'vulnerability_archives'

    belongs_to :project, optional: false
    has_many :archived_records, class_name: 'Vulnerabilities::ArchivedRecord'

    validates :date, presence: true, uniqueness: { scope: :project_id }
    validates :archived_records_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

    def date=(value)
      value = value.beginning_of_month if value

      super
    end
  end
end
