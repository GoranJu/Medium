# frozen_string_literal: true

module WorkItems
  class ValidateEpicWorkItemSyncWorker
    include Gitlab::EventStore::Subscriber
    include Gitlab::InternalEventsTracking

    data_consistency :delayed
    feature_category :team_planning
    urgency :low
    idempotent!

    RELATED_LINKS_EVENT = 'epic_sync_mismatch_related_links'
    ISSUE_HIERARCHY_EVENT = 'epic_sync_mismatch_issue_hierarchy'
    EPIC_HIERARCHY_EVENT = 'epic_sync_mismatch_epic_hierarchy'
    BASE_ATTRIBUTES_EVENT = 'epic_sync_mismatch_base_attributes'
    ATTRIBUTE_EVENTS = {
      'related_links' => RELATED_LINKS_EVENT,
      'epic_issue' => ISSUE_HIERARCHY_EVENT,
      'parent_id' => EPIC_HIERARCHY_EVENT,
      'title' => BASE_ATTRIBUTES_EVENT,
      'description' => BASE_ATTRIBUTES_EVENT,
      'closed_at' => BASE_ATTRIBUTES_EVENT,
      'iid' => BASE_ATTRIBUTES_EVENT,
      'state_id' => BASE_ATTRIBUTES_EVENT
    }.freeze

    def self.can_handle?(event)
      ::Namespace.find_by_id(event.data[:namespace_id])&.group_namespace? &&
        ::Feature.enabled?(:validate_epic_work_item_sync,
          ::Group.actor_from_id(event.data[:namespace_id])) &&
        ::Epic.find_by_issue_id(event.data[:id]).present?
    end

    def handle_event(event)
      epic, work_item = find_epic_and_work_item_from_event(event)

      return unless epic.present? && work_item.present?
      return if epic.imported_from != "none" && !event.data[:force_validation_sync]

      mismatching_attributes = Gitlab::EpicWorkItemSync::Diff.new(epic, work_item).attributes

      if mismatching_attributes.empty?
        Gitlab::EpicWorkItemSync::Logger.info(
          message: "Epic and work item attributes are in sync after #{action(event)}",
          epic_id: epic.id,
          work_item_id: epic.issue_id,
          event: event.class.name
        )
      elsif Epic.find_by_id(epic.id)
        Gitlab::EpicWorkItemSync::Logger.warn(
          message: "Epic and work item attributes are not in sync after #{action(event)}",
          epic_id: epic.id,
          work_item_id: epic.issue_id,
          mismatching_attributes: mismatching_attributes,
          event: event.class.name
        )
        track_mismatch(epic.group_id, mismatching_attributes)
      else
        Gitlab::EpicWorkItemSync::Logger.info(
          message: "Epic and WorkItem got deleted while finding mismatching attributes",
          epic_id: epic.id,
          work_item_id: epic.issue_id,
          event: event.class.name
        )
      end
    end

    private

    def action(event)
      event.is_a?(Epics::EpicCreatedEvent) || event.is_a?(WorkItems::WorkItemCreatedEvent) ? 'create' : 'update'
    end

    def find_epic_and_work_item_from_event(event)
      # Preload work item data to query it at the same time as the epic from the database, to prevent any
      # mismatches due to race conditions.
      work_item_preloaded_associations = [:dates_source, :parent_link, :color]

      if event.is_a?(Epics::EpicCreatedEvent) || event.is_a?(Epics::EpicUpdatedEvent)
        # rubocop: disable CodeReuse/ActiveRecord -- this is a one-off preload we don't re-use.
        epic = Epic.with_work_item.preload(work_item: work_item_preloaded_associations).find_by_id(event.data[:id])
        # rubocop: enable CodeReuse/ActiveRecord
        [epic, epic&.work_item]
      else
        # rubocop: disable CodeReuse/ActiveRecord -- this is a one-off preload we don't re-use.
        work_item = WorkItem.preload(work_item_preloaded_associations).find_by_id(event.data[:id])
        # rubocop: enable CodeReuse/ActiveRecord
        [work_item&.synced_epic, work_item]
      end
    end

    def track_mismatch(group_id, attributes)
      return if Gitlab.com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- There is no need to track this event on SaaS since we have access to the logs.

      attributes.filter_map { |attribute| ATTRIBUTE_EVENTS[attribute] }.uniq.each do |event_name|
        track_internal_event(event_name, { namespace_id: group_id })
      end
    end
  end
end
