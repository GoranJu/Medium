# frozen_string_literal: true

module RemoteDevelopment
  class WorkspaceVariable < ApplicationRecord
    include Sortable

    belongs_to :workspace, class_name: 'RemoteDevelopment::Workspace', inverse_of: :workspace_variables

    validates :variable_type, presence: true, inclusion: {
      in: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES.values
    }
    validates :encrypted_value, presence: true
    validates :key,
      presence: true,
      length: { maximum: 255 }

    scope :with_variable_type_environment, -> {
      where(variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:environment])
    }
    scope :with_variable_type_file, -> {
      where(variable_type: RemoteDevelopment::Enums::Workspace::WORKSPACE_VARIABLE_TYPES[:file])
    }

    scope :by_workspace_ids, ->(ids) { where(workspace_id: ids) }
    scope :by_project_ids, ->(ids) { where(project_id: ids) }

    scope :user_provided, -> {
      where(user_provided: true)
    }

    attr_encrypted :value,
      mode: :per_attribute_iv,
      key: ::Settings.attr_encrypted_db_key_base_32,
      algorithm: 'aes-256-gcm',
      allow_empty_value: true
  end
end
