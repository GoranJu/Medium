# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    # Runs several probes to determine whether features connected through Cloud Connector
    # are generally working. This includes checking for availability of certain network
    # endpoints, but also which license is used etc.
    class StatusService
      CUSTOMERS_DOT_URL = ::Gitlab::Routing.url_helpers.subscription_portal_url.freeze
      CLOUD_CONNECTOR_URL = ::CloudConnector::Config.base_url.freeze

      attr_reader :probes

      def initialize(user:, probes: nil)
        @user = user
        @probes = probes || selected_probes
      end

      def execute
        probe_results = probes.map(&:execute)
        success = probe_results.all?(&:success?)
        payload = { probe_results: probe_results }

        return ServiceResponse.error(message: 'Some probes failed', payload: payload) unless success

        ServiceResponse.success(payload: payload)
      end

      private

      def selected_probes
        # An air-gapped instance, which requires that they run their own self-hosted AI Gateway,
        # requires a different set of probes to be executed.
        if ::Gitlab::Ai::SelfHosted::AiGateway.required?
          ::Gitlab::Ai::SelfHosted::AiGateway.probes(@user)
        elsif ::Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
          self_hosted_probes
        else
          default_probes
        end
      end

      def default_probes
        [
          CloudConnector::StatusChecks::Probes::LicenseProbe.new,
          CloudConnector::StatusChecks::Probes::HostProbe.new(CUSTOMERS_DOT_URL),
          CloudConnector::StatusChecks::Probes::HostProbe.new(CLOUD_CONNECTOR_URL),
          CloudConnector::StatusChecks::Probes::AccessProbe.new,
          CloudConnector::StatusChecks::Probes::TokenProbe.new,
          CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user)
        ]
      end

      def self_hosted_probes
        [
          CloudConnector::StatusChecks::Probes::HostProbe.new(::Gitlab::AiGateway.self_hosted_url),
          CloudConnector::StatusChecks::Probes::EndToEndProbe.new(@user)
        ]
      end
    end
  end
end
