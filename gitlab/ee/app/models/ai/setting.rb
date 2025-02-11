# frozen_string_literal: true

module Ai
  class Setting < ApplicationRecord
    self.table_name = "ai_settings"

    validates :ai_gateway_url, length: { maximum: 2048 }, allow_nil: true
    validates :amazon_q_role_arn, length: { maximum: 2048 }, allow_nil: true

    validate :validate_ai_gateway_url
    validate :validates_singleton

    belongs_to :amazon_q_oauth_application, class_name: 'Doorkeeper::Application', optional: true
    belongs_to :amazon_q_service_account_user, class_name: 'User', optional: true

    def self.instance
      # rubocop:disable Performance/ActiveRecordSubtransactionMethods -- only
      # uses a subtransaction if creating a record, which should only happen
      # once per instance
      safe_find_or_create_by(singleton: true) do |setting|
        setting.assign_attributes(defaults)
      end
      # rubocop:enable Performance/ActiveRecordSubtransactionMethods
    end

    def self.defaults
      { ai_gateway_url: ENV['AI_GATEWAY_URL'] }
    end

    private

    def validates_singleton
      return unless self.class.count > 0 && self != self.class.first

      errors.add(:base, "There can only be one Settings record")
    end

    def validate_ai_gateway_url
      return if ai_gateway_url.blank?

      begin
        Gitlab::HTTP_V2::UrlBlocker.validate!(
          ai_gateway_url,
          schemes: %w[http https],
          allow_localhost: allow_localhost,
          enforce_sanitization: true,
          deny_all_requests_except_allowed: Gitlab::CurrentSettings.deny_all_requests_except_allowed?,
          outbound_local_requests_allowlist: Gitlab::CurrentSettings.outbound_local_requests_whitelist # rubocop:disable Naming/InclusiveLanguage -- existing setting
        )
      rescue Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError => e
        errors.add(:ai_gateway_url, "is not allowed: #{e.message}")
      end
    end

    def allow_localhost
      return true if Gitlab.dev_or_test_env?

      false
    end
  end
end
