# frozen_string_literal: true

module Search
  module Zoekt
    class IndexingTaskService
      include ::Gitlab::Utils::StrongMemoize
      include Gitlab::Loggable

      REINDEXING_CHANCE_PERCENTAGE = 0.5
      WATERMARK_RESCHEDULE_INTERVAL = 30.minutes

      def self.execute(...)
        new(...).execute
      end

      def initialize(project_id, task_type, node_id: nil, root_namespace_id: nil, delay: nil)
        @project_id = project_id
        @project = Project.find_by_id(project_id)
        @task_type = task_type.to_sym
        @node_id = node_id
        @root_namespace_id = root_namespace_id || @project&.root_ancestor&.id
        @delay = delay
      end

      def execute
        return false unless preflight_check?

        current_task_type = random_force_reindexing? ? :force_index_repo : task_type
        Router.fetch_indices_for_indexing(project_id, root_namespace_id: root_namespace_id).find_each do |idx|
          if current_task_type != :delete_repo && idx.should_be_deleted?
            logger.info(
              build_structured_payload(
                indexing_task_type: task_type,
                message: 'Indexing skipped due to index being either orphaned or pending deletion',
                index_id: idx.id,
                index_state: idx.state
              )
            )
            next
          end

          if index_circuit_breaker_enabled? && index_circuit_broken?(idx)
            IndexingTaskWorker.perform_in(WATERMARK_RESCHEDULE_INTERVAL, project_id, task_type, { index_id: idx.id })
            logger.info(
              build_structured_payload(
                indexing_task_type: task_type,
                message: 'Indexing rescheduled due to storage watermark',
                index_id: idx.id,
                index_state: idx.state
              )
            )
            next
          end

          perform_at = Time.current
          perform_at += delay if delay
          zoekt_repo = idx.find_or_create_repository_by_project!(project_id, project)
          Repository.id_in(zoekt_repo).create_bulk_tasks(task_type: current_task_type, perform_at: perform_at)
        end
      end

      def initial_indexing?
        repo = Repository.find_by_project_identifier(project_id)

        return true if repo.nil?
        return true if repo.ready? && random_force_reindexing?

        repo.pending? || repo.initializing? || repo.failed?
      end

      private

      attr_reader :project_id, :project, :node_id, :root_namespace_id, :task_type, :delay

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def preflight_check?
        return true if task_type == :delete_repo
        return false unless project
        return false if project.empty_repo?

        true
      end

      def random_force_reindexing?
        return true if task_type == :force_index_repo

        eligible_for_force_reindexing? && (rand * 100 <= REINDEXING_CHANCE_PERCENTAGE)
      end
      strong_memoize_attr :random_force_reindexing?

      def eligible_for_force_reindexing?
        task_type == :index_repo && Feature.enabled?(:zoekt_random_force_reindexing, project, type: :ops)
      end

      def index_circuit_broken?(idx)
        # Note: we skip indexing tasks depending on storage watermark levels.
        #
        # If the low watermark is exceeded, we don't allow any new initial indexing tasks through,
        # but we permit incremental indexing or force reindexing for existing repos.
        #
        # If the high watermark is exceeded, we don't allow any indexing tasks at all anymore.
        idx.high_watermark_exceeded? || (idx.low_watermark_exceeded? && initial_indexing?)
      end

      def index_circuit_breaker_enabled?
        Feature.enabled?(:zoekt_index_circuit_breaker, ::Project.actor_from_id(project_id), type: :ops)
      end
    end
  end
end
