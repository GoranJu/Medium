# frozen_string_literal: true

module EE
  module WorkItemsHelper
    extend ::Gitlab::Utils::Override

    override :work_items_show_data
    def work_items_show_data(resource_parent, current_user)
      super.merge(
        has_issue_weights_feature: resource_parent.licensed_feature_available?(:issue_weights).to_s,
        has_okrs_feature: resource_parent.licensed_feature_available?(:okrs).to_s,
        has_epics_feature: resource_parent.licensed_feature_available?(:epics).to_s,
        has_iterations_feature: resource_parent.licensed_feature_available?(:iterations).to_s,
        has_issuable_health_status_feature: resource_parent.licensed_feature_available?(:issuable_health_status).to_s,
        has_subepics_feature: resource_parent.licensed_feature_available?(:subepics).to_s,
        has_scoped_labels_feature: resource_parent.licensed_feature_available?(:scoped_labels).to_s,
        has_quality_management_feature: resource_parent.licensed_feature_available?(:quality_management).to_s,
        can_bulk_edit_epics: can?(current_user, :bulk_admin_epic, resource_parent).to_s,
        group_issues_path: issues_group_path(resource_parent),
        labels_fetch_path: group_labels_path(
          resource_parent, format: :json, only_group_labels: true, include_ancestor_groups: true),
        epics_list_path: group_epics_path(resource_parent),
        has_linked_items_epics_feature: resource_parent.licensed_feature_available?(:linked_items_epics).to_s
      )
    end

    override :add_work_item_show_breadcrumb
    def add_work_item_show_breadcrumb(resource_parent, iid)
      if resource_parent.work_items.with_work_item_type.find_by_iid(iid)&.epic_work_item?
        return add_to_breadcrumbs(_('Epics'), group_epics_path(resource_parent))
      end

      super
    end

    override :work_items_list_data
    def work_items_list_data(group, current_user)
      super.merge(
        can_bulk_edit_epics: can?(current_user, :bulk_admin_epic, group).to_s,
        group_issues_path: issues_group_path(group),
        has_epics_feature: group.licensed_feature_available?(:epics).to_s,
        has_issuable_health_status_feature: group.licensed_feature_available?(:issuable_health_status).to_s,
        has_issue_weights_feature: group.licensed_feature_available?(:issue_weights).to_s,
        has_okrs_feature: group.licensed_feature_available?(:okrs).to_s,
        has_quality_management_feature: group.licensed_feature_available?(:quality_management).to_s,
        has_scoped_labels_feature: group.licensed_feature_available?(:scoped_labels).to_s,
        has_subepics_feature: group.licensed_feature_available?(:subepics).to_s,
        has_iterations_feature: group.licensed_feature_available?(:iterations).to_s,
        labels_fetch_path: group_labels_path(
          group, format: :json, only_group_labels: true, include_ancestor_groups: true),
        has_linked_items_epics_feature: group.licensed_feature_available?(:linked_items_epics).to_s
      )
    end
  end
end
