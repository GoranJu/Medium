# frozen_string_literal: true

module Gitlab
  module Duo
    module Administration
      class VerifySelfHostedSetup
        attr_reader :ai_gateway_url

        def initialize(username)
          @user = User.find_by_username!(username || 'root')

          @ai_gateway_url = ::Gitlab::AiGateway.self_hosted_url
        end

        def execute
          puts <<~MSG
            This task will help you debug issues with your self-hosted Duo installation.
            For additional logs, enable 'expanded_ai_logging' Feature flag

          MSG

          verify_environmental_variables!
          verify_license_access!
          verify_aigateway_access!
        end

        def verify_environmental_variables!
          puts "Verifying environmental variables..."

          raise "Set 'AI_GATEWAY_URL' to point to your AI Gateway Instance" unless ai_gateway_url

          puts ">> 'AI_GATEWAY_URL' set to #{ai_gateway_url} ✔"

          puts ""
        end

        def verify_license_access!
          print "Verifying license access to code suggestions..."

          if Ability.allowed?(@user, :access_code_suggestions)
            puts "✔"
            return true
          end

          puts("User #{@user.username} has no access to code suggestions, debugging cause")

          if ::License.feature_available?(:code_suggestions)
            raise <<~MSG
              License is correct, but user does not have access to code suggestions. Please submit an issue to GitLab.
            MSG
          end

          raise "License does not provide access to code suggestions, verify your license"
        end

        def verify_aigateway_access!
          puts "Checking if AI Gateway is accessible..."

          begin
            request = Gitlab::HTTP.get("#{ai_gateway_url}/monitoring/healthz",
              headers: { 'accept' => 'application/json' },
              allow_local_requests: true)

            if request.code == 200
              puts ">> AI Gateway server is accessible ✔"
              return
            end
          rescue *Gitlab::HTTP::HTTP_ERRORS => e
            puts e.message
          end

          raise <<~MSG
              Cannot access AI Gateway. Possible causes:
              - AI Gateway is not running
              - 'AI_GATEWAY_URL' has an incorrect value
              - the network configuration doesn't allow communication between GitLab and AI Gateway.

          MSG
        end
      end
    end
  end
end
