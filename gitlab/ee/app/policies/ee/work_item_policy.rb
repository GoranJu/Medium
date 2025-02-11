# frozen_string_literal: true

module EE
  module WorkItemPolicy
    extend ActiveSupport::Concern
    class_methods do
      def synced_work_item_disallowed_abilities
        ::WorkItemPolicy.ability_map.map.keys.select { |ability| !ability.to_s.starts_with?("read_") }
      end
    end

    prepended do
      condition(:is_epic, scope: :subject) do
        @subject.work_item_type&.epic?
      end
      condition(:related_epics_available, scope: :subject) do
        @subject.namespace.licensed_feature_available?(:related_epics)
      end

      rule { is_epic & ~related_epics_available }.prevent :admin_work_item_link

      # Special case to allow support bot assigning service desk
      # work item parents in private groups using quick actions
      rule { support_bot & service_desk_enabled }.policy do
        enable :admin_parent_link
      end
    end
  end
end
