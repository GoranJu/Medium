# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class UpdateSecurityPoliciesService
      def initialize(policies_changes:)
        @policies_changes = policies_changes
      end

      def execute
        policies_changes.each do |policy_changes|
          # diff should be computed before updating policy attributes
          diff = policy_changes.diff
          policy = update_policy_attributes!(policy_changes.db_policy, policy_changes.yaml_policy)

          update_policy_rules(policy, diff.rules_diff)
          policy.update_pipeline_execution_policy_config_link! if policy_changes.diff.content_project_changed?
        end
      end

      private

      attr_reader :policies_changes

      def update_policy_attributes!(db_policy, yaml_policy)
        db_policy.update!(
          Security::Policy.attributes_from_policy_hash(db_policy.type.to_sym, yaml_policy,
            db_policy.security_orchestration_policy_configuration)
        )
        db_policy
      end

      def update_policy_rules(policy, rules_diff)
        return unless rules_diff

        if rules_diff.deleted.any?
          mark_rules_for_deletion(rules_diff.deleted, rules_diff.deleted.count + rules_diff.updated.count)
        end

        update_existing_rules(policy, rules_diff.updated)
        create_new_rules(policy, rules_diff.created, rules_diff.updated.count)
      end

      def update_existing_rules(policy, updated_rules)
        updated_rules.each do |rule_diff|
          rule_record = rule_diff.from
          policy.upsert_rule(rule_record.rule_index, rule_diff.to)
        end
      end

      def create_new_rules(policy, created_rules, existing_rules_count)
        created_rules.each_with_index do |rule_hash, index|
          new_index = existing_rules_count + index
          policy.upsert_rule(new_index, rule_hash)
        end
      end

      def mark_rules_for_deletion(deleted_rules, old_rules_count)
        deleted_rules.each_with_index do |rule_diff, index|
          rule_record = rule_diff.from

          new_index = old_rules_count + index
          rule_record.update!(rule_index: -new_index)
        end
      end
    end
  end
end
