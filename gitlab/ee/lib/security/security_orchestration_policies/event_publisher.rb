# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class EventPublisher
      def initialize(created_policies:, policies_changes:, deleted_policies:)
        @created_policies = created_policies
        @policies_changes = policies_changes
        @deleted_policies = deleted_policies
      end

      def publish
        ::Gitlab::EventStore.publish_group(
          created_policies.map { |policy| Security::PolicyCreatedEvent.new(data: { security_policy_id: policy.id }) }
        )

        ::Gitlab::EventStore.publish_group(
          policies_changes.map do |policy_changes|
            Security::PolicyUpdatedEvent.new(data: policy_changes.event_payload)
          end
        )

        ::Gitlab::EventStore.publish_group(
          deleted_policies.map { |policy| Security::PolicyDeletedEvent.new(data: { security_policy_id: policy.id }) }
        )
      end

      private

      attr_accessor :created_policies, :policies_changes, :deleted_policies
    end
  end
end
