# frozen_string_literal: true

module SystemAccess # rubocop:disable Gitlab/BoundedContexts -- Spliting existing table
  class GroupMicrosoftApplication < ApplicationRecord
    belongs_to :group
    has_one :graph_access_token,
      class_name: '::SystemAccess::GroupMicrosoftGraphAccessToken',
      inverse_of: :system_access_group_microsoft_application,
      foreign_key: :system_access_group_microsoft_application_id

    validates :enabled, inclusion: { in: [true, false] }
    validates :group_id, uniqueness: true
    validates :tenant_xid, presence: true
    validates :client_xid, presence: true
    validates :encrypted_client_secret, presence: true
    validates :login_endpoint,
      presence: true,
      public_url: { schemes: %w[https], enforce_sanitization: true, ascii_only: true }
    validates :graph_endpoint,
      presence: true,
      public_url: { schemes: %w[https], enforce_sanitization: true, ascii_only: true }

    attr_encrypted :client_secret,
      key: Settings.attr_encrypted_db_key_base_32,
      mode: :per_attribute_iv,
      algorithm: 'aes-256-gcm'
  end
end
