# frozen_string_literal: true

module  SystemAccess # rubocop:disable Gitlab/BoundedContexts -- Spliting existing table
  class GroupMicrosoftGraphAccessToken < ApplicationRecord
    belongs_to :system_access_group_microsoft_application,
      class_name: 'SystemAccess::GroupMicrosoftApplication',
      inverse_of: :graph_access_token

    belongs_to :group, optional: false

    validates :system_access_group_microsoft_application_id, presence: true, uniqueness: true
    validates :expires_in, presence: true, numericality: { greater_than_or_equal_to: 0 }

    attr_encrypted :token,
      key: Settings.attr_encrypted_db_key_base_32,
      mode: :per_attribute_iv,
      algorithm: 'aes-256-gcm'

    def expired?
      return true unless persisted?

      updated_at.utc + expires_in < DateTime.now.utc
    end
  end
end
