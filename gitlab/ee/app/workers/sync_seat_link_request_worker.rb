# frozen_string_literal: true

class SyncSeatLinkRequestWorker
  include ApplicationWorker

  data_consistency :always

  feature_category :plan_provisioning

  # Retry for up to approximately 2 days
  sidekiq_options retry: 20
  sidekiq_retry_in do |count, _exception|
    1.hour + rand(20.minutes)
  end

  idempotent!
  worker_has_external_dependencies!

  RequestError = Class.new(StandardError)

  def perform(timestamp, license_key, max_historical_user_count, billable_users_count, refresh_token = false)
    seat_link_data = Gitlab::SeatLinkData.new(
      timestamp: DateTime.parse(timestamp),
      key: license_key,
      max_users: max_historical_user_count,
      billable_users_count: billable_users_count,
      refresh_token: refresh_token)
    response = Gitlab::SubscriptionPortal::Client.create_seat_link(seat_link_data)

    raise RequestError, response['data']['errors'] unless response['success']

    response_data = response['data']
    reset_license!(response_data['license']) if response_data['license']

    save_future_subscriptions(response_data)
    update_add_on_purchases
    update_reconciliation!(response_data)

    perform_cloud_connector_sync if refresh_token
  end

  private

  def perform_cloud_connector_sync
    ::CloudConnector::SyncServiceTokenWorker.perform_async(
      license_id: License.current.id
    )
  end

  def reset_license!(license_key)
    License.reset_current

    if License.current_cloud_license?(license_key)
      License.current.reset.touch(:last_synced_at)
    else
      License.create!(data: license_key, cloud: true, last_synced_at: Time.current)
    end
  rescue StandardError => e
    Gitlab::ErrorTracking.track_and_raise_for_dev_exception(e)
  end

  def update_add_on_purchases
    ::GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Duo.new.execute
  end

  def update_reconciliation!(response)
    reconciliation = GitlabSubscriptions::UpcomingReconciliation.next

    if response['next_reconciliation_date'].blank? || response['display_alert_from'].blank?
      reconciliation&.destroy!
    else
      attributes = {
        next_reconciliation_date: Date.parse(response['next_reconciliation_date']),
        display_alert_from: Date.parse(response['display_alert_from'])
      }

      if reconciliation
        reconciliation.update!(attributes)
      else
        GitlabSubscriptions::UpcomingReconciliation.create!(
          attributes.merge({ organization_id: Organizations::Organization.first.id })
        )
      end
    end
  end

  def save_future_subscriptions(response)
    future_subscriptions = response['future_subscriptions'].presence || []

    Gitlab::CurrentSettings.current_application_settings.update!(future_subscriptions: future_subscriptions)
  rescue StandardError => err
    Gitlab::ErrorTracking.track_and_raise_for_dev_exception(err)
  end
end
