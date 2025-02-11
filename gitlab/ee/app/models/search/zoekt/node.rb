# frozen_string_literal: true

module Search
  module Zoekt
    class Node < ApplicationRecord
      self.table_name = 'zoekt_nodes'
      include EachBatch

      DEFAULT_CONCURRENCY_LIMIT = 20
      MAX_CONCURRENCY_LIMIT = 200
      LOST_DURATION_THRESHOLD = 12.hours
      ONLINE_DURATION_THRESHOLD = 1.minute
      WATERMARK_LIMIT_LOW = 0.6
      WATERMARK_LIMIT_HIGH = 0.7
      WATERMARK_LIMIT_CRITICAL = Rails.env.development? ? 0.99 : 0.8
      TASK_PULL_FREQUENCY_DEFAULT = '10s'
      TASK_PULL_FREQUENCY_INCREASED = '500ms'
      DEBOUNCE_DELAY = 5.seconds

      UNCLAIMED_STORAGE_BYTES_FORMULA = <<~SQL
        (zoekt_nodes.total_bytes - zoekt_nodes.used_bytes + zoekt_nodes.indexed_bytes - COALESCE(sum(zoekt_indices.reserved_storage_bytes), 0))
      SQL

      has_many :indices,
        foreign_key: :zoekt_node_id, inverse_of: :node, class_name: '::Search::Zoekt::Index'
      has_many :enabled_namespaces,
        through: :indices, source: :zoekt_enabled_namespace, class_name: '::Search::Zoekt::EnabledNamespace'
      has_many :tasks,
        foreign_key: :zoekt_node_id, inverse_of: :node, class_name: '::Search::Zoekt::Task'
      has_many :zoekt_repositories,
        through: :indices, source: :zoekt_repositories, class_name: '::Search::Zoekt::Repository'

      validates :index_base_url, presence: true
      validates :search_base_url, presence: true
      validates :uuid, presence: true, uniqueness: true
      validates :last_seen_at, presence: true
      validates :used_bytes, presence: true
      validates :total_bytes, presence: true
      validates :metadata, json_schema: { filename: 'zoekt_node_metadata' }

      attribute :metadata, ::Gitlab::Database::Type::IndifferentJsonb.new # for indifferent access

      scope :by_name, ->(*names) { where("metadata->>'name' IN (?)", names) }
      scope :lost, -> { where(last_seen_at: ..LOST_DURATION_THRESHOLD.ago) }
      scope :online, -> { where(last_seen_at: ONLINE_DURATION_THRESHOLD.ago..) }
      scope :searchable, -> { online }
      scope :searchable_for_project, ->(project) do
        searchable.joins(:zoekt_repositories)
                  .merge(Repository.searchable)
                  .where(zoekt_repositories: { project: project })
      end
      scope :with_positive_unclaimed_storage_bytes, -> do
        sql = <<~SQL
          zoekt_nodes.*, #{UNCLAIMED_STORAGE_BYTES_FORMULA} AS unclaimed_storage_bytes
        SQL
        left_joins(:indices).group(:id).having("#{UNCLAIMED_STORAGE_BYTES_FORMULA} >= 0").select(sql)
      end
      scope :order_by_unclaimed_space, -> do
        with_positive_unclaimed_storage_bytes.order('unclaimed_storage_bytes')
      end
      scope :negative_unclaimed_storage_bytes, -> do
        left_joins(:indices).group(:id).having("#{UNCLAIMED_STORAGE_BYTES_FORMULA} < 0")
      end

      def self.find_or_initialize_by_task_request(params)
        params = params.with_indifferent_access

        find_or_initialize_by(uuid: params.fetch(:uuid)).tap do |s|
          # Note: if zoekt node makes task_request with a different `node.url`,
          # we will respect that and make change here.
          s.index_base_url = params.fetch('node.url')
          s.search_base_url = params['node.search_url'] || params.fetch('node.url')

          s.last_seen_at = Time.zone.now
          s.total_bytes = params.fetch('disk.all')
          s.indexed_bytes = params['disk.indexed'] if params['disk.indexed'].present?
          s.used_bytes = params.fetch('disk.used')
          s.metadata['name'] = params.fetch('node.name')
          s.metadata['task_count'] = params['node.task_count'].to_i if params['node.task_count'].present?
          s.metadata['concurrency'] = params['node.concurrency'].to_i if params['node.concurrency'].present?
        end
      end

      def self.marking_lost_enabled?
        return false if Feature.disabled?(:zoekt_internal_api_register_nodes, Feature.current_request)
        return false if Gitlab::CurrentSettings.zoekt_indexing_paused?
        return false unless Gitlab::CurrentSettings.zoekt_indexing_enabled?
        return false unless Gitlab::CurrentSettings.zoekt_auto_delete_lost_nodes?

        true
      end

      def concurrency_limit
        override = metadata['concurrency_override'].to_i
        return override if override > 0

        calculated_limit = (metadata['concurrency'].to_i * Gitlab::CurrentSettings.zoekt_cpu_to_tasks_ratio).round
        return DEFAULT_CONCURRENCY_LIMIT if calculated_limit == 0

        [calculated_limit, MAX_CONCURRENCY_LIMIT].min
      end

      def backoff
        @backoff ||= ::Search::Zoekt::NodeBackoff.new(self)
      end

      def metadata_json
        {
          'zoekt.node_name' => metadata['name'],
          'zoekt.node_id' => id,
          'zoekt.used_bytes' => used_bytes,
          'zoekt.indexed_bytes' => indexed_bytes,
          'zoekt.storage_percent_used' => storage_percent_used,
          'zoekt.total_bytes' => total_bytes,
          'zoekt.task_count' => metadata['task_count'],
          'zoekt.concurrency' => metadata['concurrency'],
          'zoekt.concurrency_limit' => concurrency_limit
        }.compact
      end

      def watermark_exceeded_critical?
        storage_percent_used >= WATERMARK_LIMIT_CRITICAL
      end

      def watermark_exceeded_high?
        storage_percent_used >= WATERMARK_LIMIT_HIGH
      end

      def watermark_exceeded_low?
        storage_percent_used >= WATERMARK_LIMIT_LOW
      end

      def storage_percent_used
        return 0 unless total_bytes.to_i > 0

        used_bytes / total_bytes.to_f
      end

      def unclaimed_storage_bytes
        free_bytes - (reserved_storage_bytes - indexed_bytes)
      end

      def free_bytes
        total_bytes - used_bytes
      end

      def lost?
        last_seen_at <= LOST_DURATION_THRESHOLD.ago
      end

      def task_pull_frequency
        return TASK_PULL_FREQUENCY_DEFAULT if Feature.disabled?(:zoekt_reduced_pull_frequency, Feature.current_request)
        return TASK_PULL_FREQUENCY_DEFAULT if tasks.pending.limit(concurrency_limit).count < concurrency_limit

        TASK_PULL_FREQUENCY_INCREASED
      end

      def save_debounce
        return true if persisted? && updated_at && (Time.current - updated_at) < DEBOUNCE_DELAY

        save
      end

      private

      def reserved_storage_bytes
        indices.sum(:reserved_storage_bytes)
      end
    end
  end
end
