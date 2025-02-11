# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    class SyncProjectApprovalPolicyRulesService
      include Gitlab::Utils::StrongMemoize

      REPORT_TYPE_MAPPING = {
        Security::ScanResultPolicy::LICENSE_FINDING => :license_scanning,
        Security::ScanResultPolicy::ANY_MERGE_REQUEST => :any_merge_request
      }.freeze

      def initialize(project:, security_policy:)
        @project = project
        @security_policy = security_policy
      end

      def create_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        return unless use_approval_policy_rules_for_approval_rules_enabled?

        create_approval_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def update_rules(approval_policy_rules = security_policy.approval_policy_rules.undeleted)
        return unless use_approval_policy_rules_for_approval_rules_enabled?

        update_approval_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def delete_rules(approval_policy_rules = security_policy.approval_policy_rules)
        return unless use_approval_policy_rules_for_approval_rules_enabled?

        delete_approval_rules(approval_policy_rules)
        sync_merge_request_rules
      end

      def sync_policy_diff(policy_diff)
        created_rules, deleted_rules = find_changed_rules(policy_diff)
        security_policy.update_project_approval_policy_rule_links(project, created_rules, deleted_rules)

        return unless use_approval_policy_rules_for_approval_rules_enabled?

        delete_approval_rules(deleted_rules)
        create_approval_rules(created_rules)
        update_approval_rules(security_policy.approval_policy_rules.undeleted) if policy_diff.needs_rules_refresh?

        sync_merge_request_rules
      end

      def protected_branch_ids(approval_policy_rule)
        service = Security::SecurityOrchestrationPolicies::PolicyBranchesService.new(project: project)
        applicable_branches = service.scan_result_branches([approval_policy_rule.content.deep_symbolize_keys])
        protected_branches = project.all_protected_branches.select do |protected_branch|
          applicable_branches.any? { |branch| protected_branch.matches?(branch) }
        end

        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- protected branches will be limited
        protected_branches.pluck(:id)
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
      end

      private

      attr_accessor :project, :security_policy

      def find_policy_rules(policy_rule_ids)
        security_policy.approval_policy_rules.id_in(policy_rule_ids)
      end

      def find_changed_rules(policy_diff)
        # rubocop:disable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord -- created is an array of objects
        created_rules = find_policy_rules(policy_diff.rules_diff.created.pluck(:id))
        # rubocop:enable Database/AvoidUsingPluckWithoutLimit, CodeReuse/ActiveRecord
        deleted_rules = find_policy_rules(policy_diff.rules_diff.deleted.map(&:id))

        [created_rules, deleted_rules]
      end

      def use_approval_policy_rules_for_approval_rules_enabled?
        Feature.enabled?(:use_approval_policy_rules_for_approval_rules, project)
      end
      strong_memoize_attr :use_approval_policy_rules_for_approval_rules_enabled?

      def sync_merge_request_rules
        Security::SecurityOrchestrationPolicies::SyncMergeRequestsService.new(
          project: project, security_policy: security_policy
        ).execute
      end

      def delete_approval_rules(approval_policy_rules)
        security_policy.delete_approval_policy_rules_for_project(project, approval_policy_rules)
      end

      def update_approval_rules(approval_policy_rules)
        project_rules_map = project
          .approval_rules
          .for_policy_configuration(security_policy.security_orchestration_policy_configuration_id)
          .index_by(&:approval_policy_rule_id)

        scan_result_policy_reads_map = security_policy.security_orchestration_policy_configuration
          .scan_result_policy_reads
          .for_project(project)
          .select { |read| read.orchestration_policy_idx == security_policy.policy_index }
          .index_by(&:rule_idx)

        approval_policy_rules.each do |approval_policy_rule|
          scan_result_policy_read = scan_result_policy_reads_map[approval_policy_rule.rule_index]
          update_scan_result_policy_read(scan_result_policy_read, approval_policy_rule)

          next unless create_approval_rule?(approval_policy_rule)

          sync_license_scanning_rule(approval_policy_rule, scan_result_policy_read)

          project_rule = project_rules_map[approval_policy_rule.id]

          ::ApprovalRules::UpdateService.new(
            project_rule, author, rule_params(approval_policy_rule, scan_result_policy_read)
          ).execute
        end
      end

      def create_approval_rules(approval_policy_rules)
        approval_policy_rules.each do |approval_policy_rule|
          scan_result_policy_read = create_scan_result_policy(approval_policy_rule)

          next unless create_approval_rule?(approval_policy_rule)

          sync_license_scanning_rule(approval_policy_rule, scan_result_policy_read)

          ::ApprovalRules::CreateService.new(
            project, author, rule_params(approval_policy_rule, scan_result_policy_read)
          ).execute
        end
      end

      def policy_content
        security_policy.content.deep_symbolize_keys
      end
      strong_memoize_attr :policy_content

      def approval_action
        actions = policy_content[:actions]
        actions&.find { |action| action[:type] == Security::ScanResultPolicy::REQUIRE_APPROVAL }
      end
      strong_memoize_attr :approval_action

      def sync_license_scanning_rule(approval_policy_rule, scan_result_policy_read)
        return unless approval_policy_rule.type_license_finding?

        Security::SecurityOrchestrationPolicies::SyncLicensePolicyRuleService.new(
          project: project,
          security_policy: security_policy,
          approval_policy_rule: approval_policy_rule,
          scan_result_policy_read: scan_result_policy_read
        ).execute
      end

      def author
        security_policy.security_orchestration_policy_configuration.policy_last_updated_by
      end

      def create_approval_rule?(rule)
        return true unless rule.type_any_merge_request?

        # For `any_merge_request` rules, the approval rules can be created without approvers and can override
        # project approval settings in general.
        # The violations in this case are handled via SyncAnyMergeRequestRulesService
        approval_action.present?
      end

      def rule_params(approval_policy_rule, scan_result_policy_read)
        policy_configuration_id = security_policy.security_orchestration_policy_configuration_id
        rule_params = {
          skip_authorization: true,
          approvals_required: approval_action&.dig(:approvals_required) || 0,
          name: rule_name(approval_policy_rule.rule_index),
          protected_branch_ids: protected_branch_ids(approval_policy_rule),
          applies_to_all_protected_branches: applies_to_all_protected_branches?(approval_policy_rule),
          rule_type: :report_approver,
          user_ids: users_ids(approval_action&.dig(:user_approvers_ids), approval_action&.dig(:user_approvers)),
          report_type: report_type(approval_policy_rule),
          orchestration_policy_idx: security_policy.policy_index,
          group_ids: groups_ids(approval_action&.dig(:group_approvers_ids), approval_action&.dig(:group_approvers)),
          security_orchestration_policy_configuration_id: policy_configuration_id,
          approval_policy_rule_id: approval_policy_rule&.id,
          scan_result_policy_id: scan_result_policy_read&.id,
          permit_inaccessible_groups: true
        }

        rule_params[:severity_levels] = [] if approval_policy_rule.type_license_finding?

        if approval_policy_rule.type_scan_finding?
          content = approval_policy_rule.content.deep_symbolize_keys

          rule_params.merge!({
            scanners: content[:scanners],
            severity_levels: content[:severity_levels],
            vulnerabilities_allowed: content[:vulnerabilities_allowed],
            vulnerability_states: content[:vulnerability_states]
          })
        end

        rule_params
      end

      # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
      def create_scan_result_policy(approval_policy_rule)
        security_policy.security_orchestration_policy_configuration.scan_result_policy_reads.create!(
          scan_result_policy_read_params(approval_policy_rule)
        )
      end

      # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
      def update_scan_result_policy_read(scan_result_policy_read, approval_policy_rule)
        scan_result_policy_read.update!(
          scan_result_policy_read_params(approval_policy_rule)
        )
      end

      # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
      def scan_result_policy_read_params(approval_policy_rule)
        rule_content = approval_policy_rule.content.deep_symbolize_keys

        send_bot_message_action = policy_content[:actions]&.find do |action|
          action[:type] == Security::ScanResultPolicy::SEND_BOT_MESSAGE
        end

        {
          orchestration_policy_idx: security_policy.policy_index,
          rule_idx: approval_policy_rule.rule_index,
          license_states: rule_content[:license_states],
          match_on_inclusion_license: rule_content[:match_on_inclusion_license] || false,
          role_approvers: role_access_levels(approval_action&.dig(:role_approvers)),
          custom_roles: custom_role_approvers(approval_action&.dig(:role_approvers)),
          vulnerability_attributes: rule_content[:vulnerability_attributes],
          project_id: project.id,
          age_operator: rule_content.dig(:vulnerability_age, :operator),
          age_interval: rule_content.dig(:vulnerability_age, :interval),
          age_value: rule_content.dig(:vulnerability_age, :value),
          commits: rule_content[:commits],
          project_approval_settings: policy_content.fetch(:approval_settings, {}),
          send_bot_message: send_bot_message_action&.slice(:enabled) || {},
          fallback_behavior: policy_content.fetch(:fallback_behavior, {}),
          policy_tuning: policy_content.fetch(:policy_tuning, {})
        }
      end

      # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
      def role_access_levels(role_approvers)
        return [] unless role_approvers

        roles_map = Gitlab::Access.sym_options_with_owner
        role_approvers
          .filter_map { |role| roles_map[role.to_sym] if role.to_s.in?(Security::ScanResultPolicy::ALLOWED_ROLES) }
      end

      # TODO: Will be removed with https://gitlab.com/gitlab-org/gitlab/-/issues/504296
      def custom_role_approvers(role_approvers)
        return [] unless role_approvers

        role_approvers.select { |role| role.is_a?(Integer) }
      end

      def applies_to_all_protected_branches?(approval_policy_rule)
        content = approval_policy_rule.content.deep_symbolize_keys
        content[:branches] == [] || (content[:branch_type] == "protected" && content[:branch_exceptions].blank?)
      end

      def report_type(approval_policy_rule)
        REPORT_TYPE_MAPPING.fetch(approval_policy_rule.type, :scan_finding)
      end

      def rule_name(rule_index)
        policy_name = security_policy.name
        return policy_name if rule_index == 0

        "#{policy_name} #{rule_index + 1}"
      end

      def users_ids(user_ids, user_names)
        project.team.users.get_ids_by_ids_or_usernames(user_ids, user_names)
      end

      def groups_ids(group_ids, group_paths)
        Security::ApprovalGroupsFinder.new(group_ids: group_ids,
          group_paths: group_paths,
          user: author,
          container: project.namespace,
          search_globally: search_groups_globally?).execute(include_inaccessible: true)
      end

      def search_groups_globally?
        Gitlab::CurrentSettings.security_policy_global_group_approvers_enabled?
      end
    end
  end
end
