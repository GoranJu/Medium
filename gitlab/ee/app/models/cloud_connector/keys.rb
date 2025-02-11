# frozen_string_literal: true

module CloudConnector
  class Keys < ApplicationRecord
    self.table_name = 'cloud_connector_keys'

    encrypts :secret_key, key_provider: ActiveRecord::Encryption::EnvelopeEncryptionKeyProvider.new
    validates :secret_key, rsa_key: true, allow_nil: true
  end
end
