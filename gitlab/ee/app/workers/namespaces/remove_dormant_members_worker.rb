# frozen_string_literal: true

module Namespaces
  class RemoveDormantMembersWorker
    include ApplicationWorker
    include LimitedCapacity::Worker

    feature_category :seat_cost_management
    data_consistency :sticky
    urgency :low

    idempotent!

    MAX_RUNNING_JOBS = 6

    def perform_work
      return unless ::Feature.enabled?(:limited_capacity_dormant_member_removal) # rubocop: disable Gitlab/FeatureFlagWithoutActor -- not required
      return unless ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)

      namespace = find_next_namespace
      return unless namespace

      remove_dormant_members(namespace)
    end

    def remaining_work_count(*_args)
      namespaces_requiring_dormant_member_removal(max_running_jobs + 1).count
    end

    def max_running_jobs
      return 0 unless ::Feature.enabled?(:limited_capacity_dormant_member_removal) # rubocop: disable Gitlab/FeatureFlagWithoutActor -- not required

      MAX_RUNNING_JOBS
    end

    private

    # rubocop: disable CodeReuse/ActiveRecord -- LimitedCapacity worker
    def find_next_namespace
      NamespaceSetting.transaction do
        namespace_setting = namespaces_requiring_dormant_member_removal
          .preload(:namespace)
          .order_by_last_dormant_member_review_asc
          .lock('FOR UPDATE SKIP LOCKED')
          .first

        next unless namespace_setting

        # Update the last_dormant_member_review_at so the same namespace isn't picked up in parallel
        namespace_setting.update_column(:last_dormant_member_review_at, Time.current)

        namespace_setting.namespace
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def namespaces_requiring_dormant_member_removal(limit = 1)
      NamespaceSetting.requiring_dormant_member_review(limit)
    end

    def remove_dormant_members(namespace)
      dormant_period = namespace.namespace_settings.remove_dormant_members_period.days.ago
      admin_bot = ::Users::Internal.admin_bot

      ::GitlabSubscriptions::SeatAssignment.dormant_in_namespace(namespace, dormant_period).find_each do |assignment|
        next if namespace.owner_ids.include?(assignment.user_id)

        ::Gitlab::Auth::CurrentUserMode.optionally_run_in_admin_mode(admin_bot) do
          ::Members::ScheduleDeletionService.new(namespace, assignment.user_id, admin_bot).execute
        end
      end
    end
  end
end
