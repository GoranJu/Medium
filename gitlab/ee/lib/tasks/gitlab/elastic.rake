# frozen_string_literal: true

namespace :gitlab do
  namespace :elastic do
    desc 'GitLab | Elasticsearch | Index everything at once'
    task index: :environment do
      raise 'This task cannot be run on GitLab.com' if ::Gitlab::Saas.feature_available?(:advanced_search)

      if ::Gitlab::CurrentSettings.elasticsearch_pause_indexing?
        stdout_logger.warn(Rainbow('WARNING: `elasticsearch_pause_indexing` is enabled. ' \
          'This setting will be disabled to complete indexing').yellow)
      end

      unless Gitlab::CurrentSettings.elasticsearch_indexing?
        stdout_logger.warn(Rainbow('Setting `elasticsearch_indexing` is disabled. ' \
          'This setting will been enabled to complete indexing.').yellow)
      end

      stdout_logger.info('Scheduling indexing with TriggerIndexingWorker')
      worker_info_msg = <<~TEXT
        The TriggerIndexingWorker worker enables indexing and pauses indexing to ensure all indices are created by the
        worker. Then, the worker re-creates all indices, clears indexing status, and queues additional jobs to index
        project and group data, snippets, and users. Finally, indexing is resumed to complete. Track progress in
        elasticsearch.log.
      TEXT
      stdout_logger.info(worker_info_msg)

      Search::Elastic::ReindexingService.execute(delay: 1.minute)

      stdout_logger.info("Scheduling indexing with TriggerIndexingWorker... #{Rainbow('done').green}")
    end

    desc 'GitLab | Elasticsearch | Index Group entities'
    task index_group_entities: :environment do
      task_executor_service.execute(:index_group_entities)
    end

    desc 'GitLab | Elasticsearch | Enable Elasticsearch search'
    task enable_search_with_elasticsearch: :environment do
      task_executor_service.execute(:enable_search_with_elasticsearch)
    end

    desc 'GitLab | Elasticsearch | Disable Elasticsearch search'
    task disable_search_with_elasticsearch: :environment do
      task_executor_service.execute(:disable_search_with_elasticsearch)
    end

    desc 'GitLab | Elasticsearch | Index projects in the background'
    task index_projects: :environment do
      task_executor_service.execute(:index_projects)
    end

    desc 'GitLab | Elasticsearch | Overall indexing status of project repository data (code, commits, and wikis)'
    task index_projects_status: :environment do
      task_executor_service.execute(:index_projects_status)
    end

    desc 'GitLab | Elasticsearch | Index all snippets'
    task index_snippets: :environment do
      task_executor_service.execute(:index_snippets)
    end

    desc 'GitLab | Elasticsearch | Index all users'
    task index_users: :environment do
      task_executor_service.execute(:index_users)
    end

    desc 'GitLab | Elasticsearch | Index epics'
    task index_epics: :environment do
      task_executor_service.execute(:index_epics)
    end

    desc 'GitLab | Elasticsearch | Index group wikis'
    task index_group_wikis: :environment do
      task_executor_service.execute(:index_group_wikis)
    end

    desc 'GitLab | Elasticsearch | Create empty indexes and assigns an alias for each'
    task create_empty_index: [:environment] do |_t, _args|
      task_executor_service.execute(:create_empty_index)
    end

    desc 'GitLab | Elasticsearch | Delete all indexes'
    task delete_index: [:environment] do |_t, _args|
      task_executor_service.execute(:delete_index)
    end

    desc 'GitLab | Elasticsearch | Recreate indexes'
    task recreate_index: [:environment] do |_t, _args|
      task_executor_service.execute(:recreate_index)
    end

    desc 'GitLab | Elasticsearch | Zero-downtime cluster reindexing'
    task reindex_cluster: :environment do
      task_executor_service.execute(:reindex_cluster)
    end

    desc 'GitLab | Elasticsearch | Clear indexing status'
    task clear_index_status: :environment do
      task_executor_service.execute(:clear_index_status)
    end

    desc 'GitLab | Elasticsearch | Display which projects are not indexed'
    task projects_not_indexed: :environment do
      task_executor_service.execute(:projects_not_indexed)
    end

    desc 'GitLab | Elasticsearch | Mark last reindexing job as failed'
    task mark_reindex_failed: :environment do
      task_executor_service.execute(:mark_reindex_failed)
    end

    desc 'GitLab | Elasticsearch | List pending migrations'
    task list_pending_migrations: :environment do
      task_executor_service.execute(:list_pending_migrations)
    end

    desc 'GitLab | Elasticsearch | Estimate Cluster size'
    task estimate_cluster_size: :environment do
      task_executor_service.execute(:estimate_cluster_size)
    end

    desc 'GitLab | Elasticsearch | Estimate cluster shard sizes'
    task estimate_shard_sizes: :environment do
      task_executor_service.execute(:estimate_shard_sizes)
    end

    desc 'GitLab | Elasticsearch | Pause indexing'
    task pause_indexing: :environment do
      task_executor_service.execute(:pause_indexing)
    end

    desc 'GitLab | Elasticsearch | Resume indexing'
    task resume_indexing: :environment do
      task_executor_service.execute(:resume_indexing)
    end

    desc 'GitLab | Elasticsearch | List information about Advanced Search integration'
    task info: :environment do
      task_executor_service.execute(:info)
    end

    def task_executor_service
      Search::RakeTaskExecutorService.new(logger: stdout_logger)
    end

    def stdout_logger
      @stdout_logger ||= Logger.new($stdout).tap do |l|
        l.formatter = proc do |_severity, _datetime, _progname, msg|
          "#{msg}\n"
        end
      end
    end
  end
end
