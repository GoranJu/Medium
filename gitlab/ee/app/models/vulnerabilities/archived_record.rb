# frozen_string_literal: true

module Vulnerabilities
  class ArchivedRecord < Gitlab::Database::SecApplicationRecord
    self.table_name = 'vulnerability_archived_records'

    belongs_to :project, optional: false
    belongs_to :archive, class_name: 'Vulnerabilities::Archive', optional: false

    validates :vulnerability_identifier, presence: true, uniqueness: true
    validates :data, presence: true, json_schema: { filename: 'archived_record_data' }
  end
end
