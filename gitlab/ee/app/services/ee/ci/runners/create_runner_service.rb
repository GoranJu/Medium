# frozen_string_literal: true

module EE
  module Ci
    module Runners
      # Creates a CI Runner and logs an audit event
      module CreateRunnerService
        extend ::Gitlab::Utils::Override

        override :execute
        def execute
          super.tap do |response|
            audit_event(response.payload[:runner]) if response.success?
          end
        end

        private

        def audit_event(runner)
          token_scope = runner.instance_type? ? ::Gitlab::Audit::InstanceScope.new : scope

          ::AuditEvents::RunnerAuditEventService.new(
            runner, user, token_scope,
            name: 'ci_runner_created',
            message: 'Created %{runner_type} CI runner'
          ).track_event
        end
      end
    end
  end
end
