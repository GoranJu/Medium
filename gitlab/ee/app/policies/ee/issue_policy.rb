# frozen_string_literal: true

module EE
  module IssuePolicy
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    class_methods do
      def synced_work_item_disallowed_abilities
        ::IssuePolicy.ability_map.map.keys.select { |ability| !ability.to_s.starts_with?("read_") }
      end
    end

    override :epics_license_available?
    def epics_license_available?
      subject_container.licensed_feature_available?(:epics) || super
    end

    prepended do
      with_scope :subject
      condition(:summarize_notes_allowed) do
        next false unless @user

        ::Gitlab::Llm::FeatureAuthorizer.new(
          container: subject_container,
          feature_name: :summarize_comments,
          user: @user
        ).allowed?
      end

      condition(:relations_for_non_members_available) do
        scope = group_issue? ? subject_container : subject_container.group

        ::Feature.enabled?(:epic_relations_for_non_members, scope)
      end

      condition(:member_or_support_bot) do
        (is_project_member? && can?(:read_issue)) || (support_bot? && service_desk_enabled?)
      end

      rule { can_be_promoted_to_epic }.policy do
        enable :promote_to_epic
      end

      rule do
        summarize_notes_allowed & can?(:read_issue)
      end.enable :summarize_comments

      rule { relations_for_non_members_available & ~member_or_support_bot }.policy do
        prevent :admin_issue_relation
      end

      # This rule is already defined in FOSS IssuePolicy, but EE::IssuePolicy may be adding EE specific abilities
      # that would be captured here, e.g. `summarize_comments`, `promote_to_epic`, etc
      rule { group_issue & ~group_level_issues_license_available }.policy do
        prevent(*::IssuePolicy.ability_map.map.keys)
      end
    end
  end
end
