# frozen_string_literal: true

module CloudConnector
  module StatusChecks
    module Probes
      module SelfHosted
        class AiGatewayUrlPresenceProbe < BaseProbe
          extend ::Gitlab::Utils::Override

          validate :check_ai_gateway_url_presence

          private

          def self_hosted_url
            ::Gitlab::AiGateway.self_hosted_url
          end

          def check_ai_gateway_url_presence
            return if self_hosted_url.present?

            errors.add(:base, failure_message)
          end

          override :success_message
          def success_message
            format(_(
              "Self hosted AI Gateway URL is set to %{url}." \
                "To change it, in a rails console run: " \
                "`Ai::Setting.instance.update!(ai_gateway_url: URL)`"
            ), url: self_hosted_url)
          end

          def failure_message
            format(_(
              "Self hosted AI Gateway URL is not set." \
                "To set it, in a rails console run: " \
                "`Ai::Setting.instance.update!(ai_gateway_url: URL)`"
            ))
          end
        end
      end
    end
  end
end
