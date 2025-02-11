# frozen_string_literal: true

class ElasticIndexingControlWorker
  include ApplicationWorker
  include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- deprecated worker
  include Search::Worker
  prepend ::Geo::SkipSecondary

  data_consistency :always

  sidekiq_options retry: 3

  idempotent!

  def perform; end
end
