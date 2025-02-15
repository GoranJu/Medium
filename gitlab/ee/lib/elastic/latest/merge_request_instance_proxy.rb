# frozen_string_literal: true

module Elastic
  module Latest
    class MergeRequestInstanceProxy < ApplicationInstanceProxy
      SCHEMA_VERSION = 24_49
      def as_indexed_json(_options = {})
        # We don't use as_json(only: ...) because it calls all virtual and serialized attributtes
        # https://gitlab.com/gitlab-org/gitlab/issues/349
        data = {}

        [
          :id,
          :iid,
          :target_branch,
          :source_branch,
          :title,
          :description,
          :created_at,
          :updated_at,
          :state,
          :merge_status,
          :source_project_id,
          :target_project_id,
          :project_id, # Redundant field aliased to target_project_id makes it easier to share searching code
          :author_id
        ].each do |attr|
          data[attr.to_s] = safely_read_attribute_for_elasticsearch(attr)
        end

        data['visibility_level'] = target.project.visibility_level
        data['merge_requests_access_level'] = safely_read_project_feature_for_elasticsearch(:merge_requests)
        data['hashed_root_namespace_id'] = target_project.namespace.hashed_root_namespace_id

        # Use target.hidden? once the FF hide_merge_requests_from_banned_users is fully rolled out
        # https://gitlab.com/gitlab-org/gitlab/-/issues/410671
        data['hidden'] = target.author&.banned?
        data['archived'] = target.project.archived?

        # Schema version. The format is Date.today.strftime('%y_%m')
        # Please update if you're changing the schema of the document
        data['schema_version'] = SCHEMA_VERSION
        data['label_ids'] = target.label_ids.map(&:to_s)

        if ::Elastic::DataMigrationService.migration_has_finished?(:add_traversal_ids_to_merge_requests)
          data['traversal_ids'] = target.project.elastic_namespace_ancestry
        end

        if ::Elastic::DataMigrationService.migration_has_finished?(:add_assignees_to_merge_requests)
          data['assignee_ids'] = target.assignee_ids.map(&:to_s)
        end

        data.merge(generic_attributes)
      end

      def generic_attributes
        super.except('join_field')
      end
    end
  end
end
