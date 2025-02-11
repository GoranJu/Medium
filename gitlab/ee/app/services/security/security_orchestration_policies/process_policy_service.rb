# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class ProcessPolicyService
      include BaseServiceUtility

      Error = Class.new(StandardError)

      def initialize(policy_configuration:, params:)
        @policy_configuration = policy_configuration
        @params = params
      end

      def execute
        policy = params[:policy]
        type = params[:type]
        name = params[:name]
        operation = params[:operation]

        return error("Name should be same as the policy name", :bad_request) if name && operation != :replace && policy[:name] != name

        policy_hash = policy_configuration.policy_hash.dup || {}

        case operation
        when :append then append_to_policy_hash(policy_hash, policy, type)
        when :replace then replace_in_policy_hash(policy_hash, name, policy, type)
        when :remove then remove_from_policy_hash(policy_hash, policy, type)
        end

        delete_empty_deprecated_policy_type(policy_hash)

        return error('Invalid policy YAML', :bad_request, pass_back: { details: policy_configuration_validation_errors(policy_hash) }) unless policy_configuration_valid?(policy_hash)

        success(policy_hash: policy_hash)
      rescue Error => e
        error(e.message)
      end

      private

      delegate :policy_configuration_validation_errors, :policy_configuration_valid?, to: :policy_configuration

      def append_to_policy_hash(policy_hash, policy, type)
        raise Error, "Policy already exists with same name" if policy_exists?(policy_hash, policy[:name], type)

        policy_hash[type] ||= []
        policy_hash[type] += [policy]
      end

      def replace_in_policy_hash(policy_hash, name, policy, type)
        raise Error, "Policy already exists with same name" if name && name != policy[:name] && policy_exists?(policy_hash, policy[:name], type)

        existing_policy_index, existing_type = check_if_policy_exists!(policy_hash, name || policy[:name], type)
        if migrate_policy?(type, existing_type)
          remove_from_policy_hash(policy_hash, policy.dup.tap { |p| p[:name] = name }, existing_type)
          append_to_policy_hash(policy_hash, policy, type)
        else
          policy_hash[existing_type][existing_policy_index] = policy
        end
      end

      def remove_from_policy_hash(policy_hash, policy, type)
        _index, type = check_if_policy_exists!(policy_hash, policy[:name], type)
        policy_hash[type].reject! { |p| p[:name] == policy[:name] }
      end

      def check_if_policy_exists!(policy_hash, policy_name, type)
        existing_policy_index, type = policy_exists?(policy_hash, policy_name, type)

        raise Error, "Policy does not exist" if existing_policy_index.nil?

        [existing_policy_index, type]
      end

      def policy_exists?(policy_hash, policy_name, type)
        if Security::ScanResultPolicy::SCAN_RESULT_POLICY_TYPES.include?(type)
          existing_policy_index_scan_result = policy_index(policy_hash, policy_name, :scan_result_policy)
          return [existing_policy_index_scan_result, :scan_result_policy] if existing_policy_index_scan_result.present?

          existing_policy_index_approval = policy_index(policy_hash, policy_name, :approval_policy)
          [existing_policy_index_approval, :approval_policy] if existing_policy_index_approval.present?
        else
          existing_policy_index = policy_index(policy_hash, policy_name, type)
          [existing_policy_index, type] if existing_policy_index.present?
        end
      end

      def policy_index(policy_hash, policy_name, type)
        policy_hash[type]&.find_index { |p| p[:name] == policy_name }
      end

      def migrate_policy?(new_type, existing_type)
        new_type == :approval_policy && existing_type == :scan_result_policy
      end

      def delete_empty_deprecated_policy_type(policy_hash)
        return unless policy_hash[:scan_result_policy].blank?

        policy_hash.delete(:scan_result_policy)
        policy_hash[:approval_policy] ||= []
      end

      attr_reader :policy_configuration, :params
    end
  end
end
