# frozen_string_literal: true

module CloudConnector
  class AvailableServices
    class << self
      def find_by_name(service_name)
        reader = select_reader(service_name)
        service_data_map = reader.read_available_services
        if service_data_map.empty? || !service_data_map[service_name].present?
          return CloudConnector::MissingServiceData.new
        end

        service_data_map[service_name]
      end

      def select_reader(service_name)
        if use_self_signed_token?(service_name) # gitlab.com or self-hosted AI Gateway
          SelfSigned::AccessDataReader.new
        else
          SelfManaged::AccessDataReader.new
        end
      end

      private

      # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- we don't have dedicated SM/.com Cloud Connector features
      # or other checks that would allow us to identify where the code is running. We rely on instance checks for now.
      # Will be addressed in https://gitlab.com/gitlab-org/gitlab/-/issues/437725
      def use_self_signed_token?(service_name)
        return true if Gitlab.org_or_com?
        return true if service_name == :self_hosted_models

        # All remaining code paths require requesting self-signed tokens.
        Gitlab::Utils.to_boolean(ENV['CLOUD_CONNECTOR_SELF_SIGN_TOKENS'])
      end
      # rubocop:enable Gitlab/AvoidGitlabInstanceChecks
    end
  end
end
