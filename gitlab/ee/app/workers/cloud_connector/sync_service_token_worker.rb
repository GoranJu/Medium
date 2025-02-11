# frozen_string_literal: true

module CloudConnector
  class SyncServiceTokenWorker
    include ApplicationWorker

    data_consistency :sticky

    include CronjobQueue # rubocop:disable Scalability/CronWorkerContext -- Does not perform work scoped to a context

    idempotent!

    sidekiq_options retry: 3

    worker_has_external_dependencies!

    feature_category :cloud_connector

    def perform(params = {})
      # We should refrain from using License.current, because it can cause state drift
      # when Sidekiq jobs update and read license data and execute in different workers.
      # We only maintain this for backwards-compatibility.
      # See: https://gitlab.com/gitlab-org/gitlab/-/issues/498456
      license = params[:license_id] ? License.find_by_id(params[:license_id]) : License.current
      result = ::CloudConnector::SyncCloudConnectorAccessService.new(license).execute

      log_extra_metadata_on_done(:error_message, result[:message]) unless result.success?
    end
  end
end
