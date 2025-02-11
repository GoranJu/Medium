# frozen_string_literal: true

module Issuables
  class CustomFieldsFinder
    include Gitlab::SQL::Pattern

    def self.active_fields_for_work_item(work_item)
      new(
        nil,
        group: work_item.namespace.root_ancestor,
        active: true,
        work_item_type_ids: [work_item.work_item_type_id],
        skip_permissions_check: true
      ).execute
    end

    def initialize(
      current_user, group:, active: nil, search: nil, work_item_type_ids: nil,
      skip_permissions_check: false
    )
      raise ArgumentError, 'group argument is missing' if group.nil?

      @current_user = current_user
      @group = group
      @active = active
      @search = search
      @work_item_type_ids = work_item_type_ids
      @skip_permissions_check = skip_permissions_check
    end

    def execute
      return Issuables::CustomField.none unless Feature.enabled?('custom_fields_feature', @group)
      return Issuables::CustomField.none unless @group&.feature_available?(:custom_fields)

      return Issuables::CustomField.none unless @skip_permissions_check ||
        Ability.allowed?(@current_user, :read_custom_field, @group)

      items = Issuables::CustomField.of_namespace(@group)
      items = by_status(items)
      items = by_search(items)
      items = by_work_item_type_ids(items)
      items.ordered_by_status_and_name
    end

    private

    def by_status(items)
      return items if @active.nil?

      if @active
        items.active
      else
        items.archived
      end
    end

    def by_search(items)
      return items if @search.blank?

      items.fuzzy_search(@search, [:name], use_minimum_char_limit: false)
    end

    def by_work_item_type_ids(items)
      return items if @work_item_type_ids.nil?

      items.with_work_item_types(@work_item_type_ids)
    end
  end
end
