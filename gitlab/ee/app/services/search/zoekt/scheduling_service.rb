# frozen_string_literal: true

module Search
  module Zoekt
    class SchedulingService
      include Gitlab::Loggable

      CONFIG = {
        adjust_indices_reserved_storage_bytes: {
          period: 10.minutes,
          if: -> { Index.should_be_reserved_storage_bytes_adjusted.exists? },
          dispatch: { event: AdjustIndicesReservedStorageBytesEvent }
        },
        indices_to_evict_check: {
          period: 10.minutes,
          if: -> { Index.pending_eviction.exists? },
          dispatch: { event: IndexToEvictEvent }
        },
        index_mismatched_watermark_check: {
          period: 10.minutes,
          if: -> {
            Search::Zoekt::Index.with_mismatched_watermark_levels
              .or(Search::Zoekt::Index.negative_reserved_storage_bytes).exists?
          },
          dispatch: { event: IndexWatermarkChangedEvent }
        },
        index_should_be_marked_as_orphaned_check: {
          period: 10.minutes,
          if: -> { Index.should_be_marked_as_orphaned.exists? },
          dispatch: { event: OrphanedIndexEvent }
        },
        index_should_be_marked_as_pending_eviction_check: {
          if: -> { Index.should_be_pending_eviction.exists? },
          dispatch: { event: IndexMarkPendingEvictionEvent }
        },
        index_to_delete_check: {
          period: 10.minutes,
          if: -> { Index.should_be_deleted.exists? },
          dispatch: { event: IndexMarkedAsToDeleteEvent }
        },
        lost_nodes_check: {
          period: 10.minutes,
          if: -> {
            !Rails.env.development? && Node.marking_lost_enabled? && Node.lost.exists?
          },
          dispatch: {
            event: LostNodeEvent,
            data: -> {
              { zoekt_node_id: Node.lost.limit(1).select(:id).last.id }
            }
          }
        },
        mark_indices_as_ready: {
          if: -> { Index.initializing.with_all_finished_repositories.exists? },
          dispatch: { event: IndexMarkedAsReadyEvent }
        },
        remove_expired_subscriptions: {
          if: -> { ::Gitlab::Saas.feature_available?(:exact_code_search) },
          execute: -> { EnabledNamespace.destroy_namespaces_with_expired_subscriptions! }
        },
        repo_should_be_marked_as_orphaned_check: {
          period: 10.minutes,
          if: -> { Search::Zoekt::Repository.should_be_marked_as_orphaned.exists? },
          dispatch: { event: OrphanedRepoEvent }
        },
        repo_to_index_check: {
          period: 10.minutes,
          if: -> { Search::Zoekt::Repository.pending.exists? },
          dispatch: { event: RepoToIndexEvent }
        },
        repo_to_delete_check: {
          period: 10.minutes,
          if: -> { ::Search::Zoekt::Repository.should_be_deleted.exists? },
          dispatch: { event: RepoMarkedAsToDeleteEvent }
        },
        update_index_used_storage_bytes: {
          if: -> { Index.with_stale_used_storage_bytes_updated_at.exists? },
          dispatch: { event: UpdateIndexUsedStorageBytesEvent }
        },
        update_replica_states: {
          period: 2.minutes,
          if: -> { Feature.enabled? :zoekt_replica_state_updates, Feature.current_request },
          execute: -> { ReplicaStateService.execute }
        },
        saas_rollout: {
          period: 2.hours,
          if: -> { ::Gitlab::Saas.feature_available?(:exact_code_search) },
          dispatch: { event: SaasRolloutEvent }
        }
      }.freeze

      TASKS = (%i[
        auto_index_self_managed
        dot_com_rollout
        eviction
        initial_indexing
        node_assignment
        node_with_negative_unclaimed_storage_bytes_check
        update_index_used_bytes
      ] + CONFIG.keys).freeze

      BUFFER_FACTOR = 3

      INITIAL_INDEXING_LIMIT = 10

      attr_reader :task

      def self.execute!(task)
        execute(task, without_cache: true)
      end

      def self.execute(task, without_cache: false)
        instance = new(task)

        Gitlab::Redis::SharedState.with { |r| r.del(instance.cache_key) } if without_cache

        instance.execute
      end

      def initialize(task)
        @task = task.to_sym
      end

      def execute
        raise ArgumentError, "Unknown task: #{task.inspect}" unless TASKS.include?(task)

        if CONFIG.key?(task)
          execute_config_task(task)
        elsif respond_to?(task, true)
          send(task) # rubocop:disable GitlabSecurity/PublicSend -- We control the list of tasks in the source code
        else
          raise NotImplementedError, "Task #{task} is not implemented."
        end
      end

      def cache_key
        period = cache_period.presence || "-"
        [self.class.name.underscore, :execute_every, period, task].flatten.join(':')
      end

      def cache_period
        return unless CONFIG.key?(task)

        CONFIG.dig(task, :period)
      end

      private

      def execute_config_task(task_name)
        config = CONFIG[task_name]

        execute_every(config[:period]) do
          unless config[:execute] || config[:dispatch]
            raise NotImplementedError, "No execute block or dispatch defined for task #{task_name}"
          end

          # Check `if` condition, default to true if not provided
          if config[:if]&.call == false
            logger.info(build_structured_payload(task: task_name, message: "Condition not met"))
            break false
          end

          # Call the execute block if provided
          config[:execute].call if config[:execute]

          dispatch(config[:dispatch][:event], &config[:dispatch][:data]) if config[:dispatch]
        end
      end

      def execute_every(period)
        # We don't want any delay interval in development environments,
        # so lets disable the cache unless we are in production.
        return yield if Rails.env.development?
        return yield unless period

        Gitlab::Redis::SharedState.with do |redis|
          key_set = redis.set(cache_key, 1, ex: period, nx: true)
          break false unless key_set

          yield
        end
      end

      def logger
        @logger ||= ::Search::Zoekt::Logger.build
      end

      def info(task, **payload)
        logger.info(build_structured_payload(**payload.merge(task: task)))
      end

      # An initial implementation of eviction logic. For now, it's a .com-only task
      def eviction
        return false unless ::Gitlab::Saas.feature_available?(:exact_code_search)
        return false if Feature.disabled?(:zoekt_reallocation_task, Feature.current_request)

        execute_every 5.minutes do
          nodes = ::Search::Zoekt::Node.online.find_each.to_a
          over_watermark_nodes = nodes.select(&:watermark_exceeded_high?)

          break if over_watermark_nodes.empty?

          info(:eviction, message: 'Detected nodes over watermark',
            watermark_limit_high: ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
            count: over_watermark_nodes.count)

          over_watermark_nodes.each do |node|
            sizes = {}

            node.indices.each_batch do |batch|
              scope = Namespace.includes(:root_storage_statistics) # rubocop:disable CodeReuse/ActiveRecord -- this is a temporary incident mitigation task
                               .by_parent(nil)
                               .id_in(batch.select(:namespace_id))

              scope.each do |group|
                sizes[group.id] = group.root_storage_statistics&.repository_size || 0
              end
            end

            sorted = sizes.to_a.sort_by { |_k, v| v }

            namespaces_to_move = []
            total_repository_size = 0
            node_original_used_bytes = node.used_bytes
            sorted.each do |namespace_id, repository_size|
              node.used_bytes -= repository_size
              namespaces_to_move << namespace_id
              total_repository_size += repository_size

              break unless node.watermark_exceeded_low?
            end

            unassign_namespaces_from_node(node, namespaces_to_move, node_original_used_bytes, total_repository_size)
          end
        end
      end

      def unassign_namespaces_from_node(node, namespaces_to_move, node_original_used_bytes, total_repository_size)
        return if namespaces_to_move.empty?

        info(:eviction, message: 'Unassigning namespaces from node',
          watermark_limit_high: ::Search::Zoekt::Node::WATERMARK_LIMIT_HIGH,
          count: namespaces_to_move.count,
          node_used_bytes: node_original_used_bytes,
          node_expected_used_bytes: node.used_bytes,
          total_repository_size: total_repository_size,
          meta: node.metadata_json
        )

        namespaces_to_move.each_slice(100) do |namespace_ids|
          ::Search::Zoekt::EnabledNamespace.for_root_namespace_id(namespace_ids).update_last_used_storage_bytes!

          ::Search::Zoekt::Replica.for_namespace(namespace_ids).each_batch do |batch|
            batch.delete_all
          end
        end
      end

      # Task has been replaced by saas_rollout
      def dot_com_rollout; end

      # rubocop: disable Metrics/AbcSize -- After removal of FFs metrics will be fine
      def node_assignment
        return false if Feature.disabled?(:zoekt_node_assignment, Feature.current_request)

        execute_every 1.hour do
          nodes = ::Search::Zoekt::Node.online.find_each.to_a

          break false if nodes.empty?

          zoekt_indices = []

          EnabledNamespace.with_missing_indices.preload_storage_statistics.find_each do |zoekt_enabled_namespace|
            storage_statistics = zoekt_enabled_namespace.namespace.root_storage_statistics
            unless storage_statistics
              logger.error(build_structured_payload(
                task: :node_assignment,
                message: "RootStorageStatistics isn't available",
                zoekt_enabled_namespace_id: zoekt_enabled_namespace.id
              ))

              next
            end

            space_required = BUFFER_FACTOR * storage_statistics.repository_size

            node = nodes.max_by { |n| n.total_bytes - n.used_bytes }

            if (node.used_bytes + space_required) <= node.total_bytes * ::Search::Zoekt::Node::WATERMARK_LIMIT_LOW
              zoekt_index = Search::Zoekt::Index.new(
                namespace_id: zoekt_enabled_namespace.root_namespace_id,
                zoekt_node_id: node.id,
                zoekt_enabled_namespace: zoekt_enabled_namespace,
                replica: Replica.for_enabled_namespace!(zoekt_enabled_namespace),
                reserved_storage_bytes: space_required
              )
              zoekt_index.state = :ready if space_required == 0
              zoekt_indices << zoekt_index
              node.used_bytes += space_required
            elsif Feature.enabled?(:zoekt_create_multiple_indices, zoekt_enabled_namespace.namespace)
              multiple_indices = NamespaceAssignmentService.new(zoekt_enabled_namespace).execute
              if multiple_indices.empty?
                logger.error(build_structured_payload(
                  task: :node_assignment,
                  message: 'Namespace is too big even for multiple indices',
                  zoekt_enabled_namespace_id: zoekt_enabled_namespace.id
                ))
              else
                zoekt_indices.concat(multiple_indices)
              end
            else
              logger.error(build_structured_payload(
                task: :node_assignment,
                message: 'Space is not available in Node', zoekt_enabled_namespace_id: zoekt_enabled_namespace.id,
                meta: node.metadata_json
              ))
            end
          end

          zoekt_indices.each do |zoekt_index|
            unless zoekt_index.save
              logger.error(build_structured_payload(task: :node_assignment,
                message: 'Could not save Search::Zoekt::Index', zoekt_index: zoekt_index.attributes.compact))
            end
          end
        end
      end
      # rubocop: enable Metrics/AbcSize

      def node_with_negative_unclaimed_storage_bytes_check
        execute_every 1.hour do
          Search::Zoekt::Node.negative_unclaimed_storage_bytes.each_batch do |batch|
            dispatch NodeWithNegativeUnclaimedStorageEvent do
              { node_ids: batch.pluck_primary_key }
            end
          end
        end
      end

      def initial_indexing
        ::Search::Zoekt::Index.pending.ordered.limit(INITIAL_INDEXING_LIMIT).each do |index|
          dispatch InitialIndexingEvent do
            { index_id: index.id }
          end
        end
      end

      # This task does not need to run on .com
      def auto_index_self_managed
        return if Gitlab::Saas.feature_available?(:exact_code_search)
        return unless Gitlab::CurrentSettings.zoekt_auto_index_root_namespace?

        execute_every 10.minutes do
          Namespace.group_namespaces.root_namespaces_without_zoekt_enabled_namespace.each_batch do |batch|
            data = batch.pluck_primary_key.map { |id| { root_namespace_id: id } }
            Search::Zoekt::EnabledNamespace.insert_all(data)
          end
        end
      end

      # This task name is deprecated
      def update_index_used_bytes; end

      # Publishes an event to the event store if the given condition is met.
      #
      # Example usage:
      # dispatch RepoMarkedAsToDeleteEvent, if: -> { Search::Zoekt::Repository.should_be_deleted.exists? }
      # dispatch RepoToIndexEvent # will always be published
      # dispatch RepoToIndexEvent, if: -> { false } # will never be published
      # dispatch RepoToIndexEvent do # optional: if given a block, it will pass the return value as data to event store
      #   { id: 123, description: "data to dispatch" }
      # end
      def dispatch(event, **kwargs)
        if kwargs[:if].present? && !kwargs[:if].call
          logger.info(build_structured_payload(task: task, message: 'Nothing to dispatch'))
          return false
        end

        data = block_given? ? yield : {}

        Gitlab::EventStore.publish(event.new(data: data))
      end
    end
  end
end
