# frozen_string_literal: true

module Search
  module Elastic
    module References
      class WorkItem < Reference
        include Search::Elastic::Concerns::DatabaseReference

        SCHEMA_VERSION = 24_47
        NOTES_MAXIMUM_BYTES = 512.kilobytes

        override :serialize
        def self.serialize(record)
          new(record.id, record.es_parent).serialize
        end

        override :instantiate
        def self.instantiate(string)
          _, id, routing = delimit(string)

          # this puts the record in the work items index
          new(id, routing)
        end

        override :preload_indexing_data
        def self.preload_indexing_data(refs)
          ids = refs.map(&:identifier)

          records = ::WorkItem.id_in(ids).preload_indexing_data
          records_by_id = records.index_by(&:id)

          refs.each do |ref|
            ref.database_record = records_by_id[ref.identifier.to_i]
          end

          refs
        end

        def self.index
          environment_specific_index_name('work_items')
        end

        attr_reader :identifier, :routing

        def initialize(identifier, routing)
          @identifier = identifier.to_i
          @routing = routing
        end

        override :serialize
        def serialize
          self.class.join_delimited([klass, identifier, routing].compact)
        end

        override :as_indexed_json
        def as_indexed_json
          build_indexed_json(database_record)
        end

        override :index_name
        def index_name
          self.class.index
        end

        def model_klass
          ::WorkItem
        end

        private

        def populate_notes(target, data)
          notes_internal, notes = target.notes.user.partition(&:internal)

          internal_notes = notes_internal.sort_by(&:created_at).reverse.map(&:note).join("\n").presence
          data['notes_internal'] = internal_notes.truncate_bytes(NOTES_MAXIMUM_BYTES) if internal_notes

          notes = notes.sort_by(&:created_at).reverse.map(&:note).join("\n").presence
          data['notes'] = notes.truncate_bytes(NOTES_MAXIMUM_BYTES) if notes

          data
        end

        # rubocop: disable Metrics/AbcSize -- it's above the limit because we have feature flags that we will remove
        def build_indexed_json(target)
          data = {}

          [
            :id,
            :iid,
            :created_at,
            :updated_at,
            :title,
            :description,
            :author_id,
            :due_date,
            :confidential,
            :project_id,
            :state
          ].each do |attribute|
            data[attribute.to_s] = safely_read_attribute_for_elasticsearch(target, attribute)
          end

          data['label_ids'] = target.label_ids.map(&:to_s)
          data['hidden'] = target.hidden?
          data['root_namespace_id'] = target.namespace.root_ancestor.id
          data['traversal_ids'] = target.namespace.elastic_namespace_ancestry
          data['hashed_root_namespace_id'] = target.namespace.hashed_root_namespace_id
          data['work_item_type_id'] = target.work_item_type_id
          data['correct_work_item_type_id'] = target.correct_work_item_type_id

          if ::Feature.enabled?(:search_work_items_index_notes, ::Feature.current_request)
            data = populate_notes(target, data)
          end

          data['upvotes'] = target.upvotes_count

          if target.namespace.group_namespace?
            data['namespace_visibility_level'] = target.namespace.visibility_level
            data['namespace_id'] = target.namespace_id
          end

          if target.project.present?
            data['archived'] = target.project.archived?
            data['project_visibility_level'] = target.project.visibility_level
            data['issues_access_level'] = target.project.issues_access_level
          end

          data['assignee_id'] = safely_read_attribute_for_elasticsearch(target, :issue_assignee_user_ids)

          # Schema version. The format is Date.today.strftime('%y_%m')
          # Please update if you're changing the schema of the document
          data['schema_version'] = SCHEMA_VERSION
          data['type'] = model_klass.es_type

          data
        end
        # rubocop: enable Metrics/AbcSize
      end
    end
  end
end
