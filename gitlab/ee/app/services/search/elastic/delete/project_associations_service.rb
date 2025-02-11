# frozen_string_literal: true

module Search
  module Elastic
    module Delete
      class ProjectAssociationsService
        include Gitlab::Loggable

        attr_reader :options

        def self.execute(options)
          new(options).execute
        end

        def initialize(options)
          @options = options.with_indifferent_access
        end

        def execute
          project_id = options[:project_id]
          traversal_id = options[:traversal_id]
          remove_work_item_documents(project_id, traversal_id)
        end

        private

        def logger
          @logger ||= ::Gitlab::Elasticsearch::Logger.build
        end

        def remove_work_item_documents(project_id, traversal_id)
          filter_list = []
          filter_list << { term: { project_id: project_id } } unless project_id.nil?

          unless traversal_id.nil?
            filter_list << { bool: { must_not: { prefix: { traversal_ids: { value: traversal_id } } } } }
          end

          if filter_list.empty?
            Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
              ArgumentError.new('project_id, traversal_id are nil')
            )
            return
          end

          response = client.delete_by_query({
            index: ::Search::Elastic::Types::WorkItem.index_name,
            conflicts: 'proceed',
            timeout: '10m',
            body: {
              query: {
                bool: {
                  filter: filter_list
                }
              }
            }
          })

          log_payload = build_structured_payload(
            project_id: project_id,
            traversal_id: traversal_id,
            index: ::Search::Elastic::Types::WorkItem.index_name
          )

          if !response['failure'].nil?
            log_payload[:failure] = response['failure']
            log_payload[:message] = "Failed to delete data for project transfer"
          else
            log_payload[:deleted] = response['deleted']
            log_payload[:message] = "Successfully deleted duplicate data for project transfer"
          end

          if log_payload[:failure].present?
            logger.error(log_payload)
          else
            logger.info(log_payload)
          end
        end

        def client
          @client ||= ::Gitlab::Search::Client.new
        end
      end
    end
  end
end
