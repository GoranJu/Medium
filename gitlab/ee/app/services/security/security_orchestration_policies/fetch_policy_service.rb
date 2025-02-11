# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class FetchPolicyService
      include BaseServiceUtility

      def initialize(policy_configuration:, name:, type:)
        @policy_configuration = policy_configuration
        @name = name
        @types = if Security::ScanResultPolicy::SCAN_RESULT_POLICY_TYPES.include?(type)
                   Security::ScanResultPolicy::SCAN_RESULT_POLICY_TYPES
                 else
                   [type]
                 end
      end

      def execute
        success({ policy: policy })
      end

      private

      attr_reader :policy_configuration, :types, :name

      def policy
        policy_configuration
          .policy_by_type(types)
          .find { |policy| policy[:name] == name }
      end
    end
  end
end
