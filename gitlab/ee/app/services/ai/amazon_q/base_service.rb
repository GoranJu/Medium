# frozen_string_literal: true

module Ai
  module AmazonQ
    class BaseService
      include Gitlab::Utils::StrongMemoize

      AVAILABILITY_OPTIONS = %w[default_on default_off never_on].freeze

      def initialize(user, params = {})
        @user = user
        @params = params
      end

      private

      attr_accessor :user, :params

      def availability_param_error
        return ServiceResponse.error(message: 'Missing availability parameter') unless params[:availability].present?
        return if AVAILABILITY_OPTIONS.include?(params[:availability])

        ServiceResponse.error(message: "availability must be one of: #{AVAILABILITY_OPTIONS.join(', ')}")
      end
      strong_memoize_attr :availability_param_error

      def application_settings
        ::Gitlab::CurrentSettings.current_application_settings
      end
      strong_memoize_attr :application_settings

      def ai_settings
        Ai::Setting.instance
      end
      strong_memoize_attr :ai_settings

      def create_audit_event(audit_availability:, audit_ai_settings:, exclude_columns: [])
        message = 'Changed '
        message += "availability to #{application_settings.duo_availability}, " if audit_availability

        if audit_ai_settings
          columns = %w[amazon_q_role_arn amazon_q_service_account_user_id amazon_q_oauth_application_id amazon_q_ready]
          columns -= exclude_columns
          message += columns.map do |column|
            "#{column} to #{ai_settings[column].presence || 'null'}, "
          end.join
        end

        ::Gitlab::Audit::Auditor.audit({
          name: 'q_onbarding_updated',
          author: user,
          scope: Gitlab::Audit::InstanceScope.new,
          target: ai_settings,
          message: message[0...-2]
        })
      end
    end
  end
end
