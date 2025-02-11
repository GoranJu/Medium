# frozen_string_literal: true

module Search
  module Zoekt
    class Repository < ApplicationRecord
      include EachBatch

      SEARCHABLE_STATES = %i[ready].freeze

      self.table_name = 'zoekt_repositories'

      attribute :retries_left, default: 3

      belongs_to :zoekt_index, inverse_of: :zoekt_repositories, class_name: '::Search::Zoekt::Index'

      belongs_to :project, inverse_of: :zoekt_repositories, class_name: 'Project'

      has_many :tasks,
        foreign_key: :zoekt_repository_id, inverse_of: :zoekt_repository, class_name: '::Search::Zoekt::Task'

      before_validation :set_project_identifier

      validates_presence_of :zoekt_index_id, :project_identifier, :state

      validate :project_id_matches_project_identifier

      validates :project_identifier, uniqueness: {
        scope: :zoekt_index_id, message: 'violates unique constraint between [:zoekt_index_id, :project_identifier]'
      }

      enum state: {
        pending: 0,
        initializing: 1,
        ready: 10,
        orphaned: 230,
        pending_deletion: 240,
        failed: 255
      }

      scope :uncompleted, -> { where.not(state: %i[ready failed]) }

      scope :for_project_id, ->(project_id) { where(project_identifier: project_id) }

      scope :for_replica_id, ->(replica_id) { joins(:zoekt_index).where(zoekt_index: { zoekt_replica_id: replica_id }) }

      scope :should_be_marked_as_orphaned, -> { where(project_id: nil).where.not(state: :orphaned) }

      scope :should_be_deleted, -> do
        where(state: [:orphaned, :pending_deletion])
      end

      scope :for_zoekt_indices, ->(indices) { where(zoekt_index: indices) }

      scope :searchable, -> { where(state: SEARCHABLE_STATES) }

      def self.create_bulk_tasks(task_type: :index_repo, perform_at: Time.zone.now)
        scope = self
        unless task_type.to_sym == :delete_repo
          # Reject the failed repos for non delete_repo task_type
          scope = scope.where.not(state: :failed)
        end
        # Reject the repo_ids which already have the pending tasks for the given task_type
        scope = scope.where.not(
          id: Search::Zoekt::Task.pending.where(
            zoekt_repository_id: scope.select(:id), task_type: task_type
          ).select(:zoekt_repository_id)
        )
        tasks = scope.includes(:zoekt_index).map do |zoekt_repo|
          Search::Zoekt::Task.new(
            zoekt_repository_id: zoekt_repo.id,
            zoekt_node_id: zoekt_repo.zoekt_index.zoekt_node_id,
            project_identifier: zoekt_repo.project_identifier,
            task_type: task_type,
            perform_at: perform_at,
            created_at: Time.zone.now,
            updated_at: Time.zone.now
          )
        end
        Search::Zoekt::Task.bulk_insert!(tasks)
        repo_ids = tasks.map(&:zoekt_repository_id)
        Search::Zoekt::Repository.id_in(repo_ids).pending.each_batch { |repos| repos.update_all(state: :initializing) }
      end

      private

      def project_id_matches_project_identifier
        return unless project_id.present?
        return if project_id == project_identifier

        errors.add(:project_id, :invalid)
      end

      def set_project_identifier
        self.project_identifier ||= project_id
      end
    end
  end
end
