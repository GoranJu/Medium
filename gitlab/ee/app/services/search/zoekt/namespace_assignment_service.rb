# frozen_string_literal: true

module Search
  module Zoekt
    class NamespaceAssignmentService
      MAX_INDICES_PER_REPLICA = 5
      PRE_READY_LIMIT = 1

      def self.execute(...)
        new(...).execute
      end

      def initialize(zoekt_enabled_namespace)
        @zoekt_enabled_namespace = zoekt_enabled_namespace
        @set_new_index = true
        @index_bytes = 0
        @indices = []
        @previous_project_id = nil
        @early_return = false
      end

      # Returns the array of initialized indices for a zoekt_enabled_namespace
      # If a namespace can not be accommodated within MAX_INDICES_PER_REPLICA indices then it returns empty array
      def execute
        zoekt_enabled_namespace.namespace.all_projects.with_statistics.find_each do |project|
          initialize_index_for_project(project)
          # Set indices to empty array and break if early return
          if early_return
            @indices = []
            break
          end

          @previous_project_id = project.id
        end
        indices.each do |zoekt_index|
          zoekt_index.replica = Replica.for_enabled_namespace!(zoekt_enabled_namespace)
          zoekt_index.zoekt_enabled_namespace = zoekt_enabled_namespace
          zoekt_index.namespace_id = zoekt_enabled_namespace.root_namespace_id
        end
      end

      private

      attr_reader :zoekt_enabled_namespace
      attr_accessor :set_new_index, :index_bytes, :indices, :previous_project_id, :early_return

      def initialize_index_for_project(project)
        index = indices.last
        project_stats = project.statistics

        if project_stats.nil?
          @early_return = true
          return
        end

        if set_new_index
          if indices.size == MAX_INDICES_PER_REPLICA
            @early_return = true
            return
          end

          node = Node.order_by_unclaimed_space.id_not_in(indices.map(&:zoekt_node_id)).last

          if Search::Zoekt::Index.for_node(node).pre_ready.count > PRE_READY_LIMIT
            @early_return = true
            return
          end

          if node.nil?
            @early_return = true
            return
          end

          index = initialize_index(node)
          index.metadata[:project_id_from] = project.id
        end

        index_required_bytes = index_required_bytes(index_bytes, project_stats)
        # case when the space is available in the current index for project
        if index_required_bytes <= index.reserved_storage_bytes
          # Refreshes the state of index on each project iteration.
          # Consider a case project1 is zero bytes and project2 is non zero bytes.
          # Final index state should be pending
          refresh_indices_collection!(indices, index, index_required_bytes)
          @set_new_index = false
          @index_bytes = index_required_bytes
        else # Case when there is no space available in the current index
          # early return if it is a new index and there is no available space
          if set_new_index
            @early_return = true
            return
          end
          # There is no space available in the index, so set the project_id_to for the current index
          index.metadata[:project_id_to] = previous_project_id
          indices[-1] = index unless indices.empty?
          # Initialize a new index for the current project
          @previous_project_id = nil
          @set_new_index = true
          @index_bytes = 0
          initialize_index_for_project(project)
        end
      end

      def initialize_index(node)
        Index.new(reserved_storage_bytes: node.unclaimed_storage_bytes * Node::WATERMARK_LIMIT_LOW, node: node)
      end

      def index_required_bytes(index_bytes, project_stats)
        index_bytes + (project_stats.repository_size * SchedulingService::BUFFER_FACTOR)
      end

      def refresh_indices_collection!(indices, index, index_required_bytes)
        # Set the index state to ready when the required bytes for an index is zero
        index.state = index_required_bytes == 0 ? :ready : :pending

        return indices << index unless indices.any? && (indices.last.zoekt_node_id == index&.zoekt_node_id)

        indices[-1] = index
      end
    end
  end
end
