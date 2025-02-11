# frozen_string_literal: true

module GitlabSubscriptions
  class AddOnPurchase < ApplicationRecord
    include EachBatch
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    CLEANUP_DELAY_PERIOD = 14.days

    belongs_to :add_on, foreign_key: :subscription_add_on_id, inverse_of: :add_on_purchases
    belongs_to :namespace, optional: true
    belongs_to :organization, class_name: 'Organizations::Organization'
    has_many :assigned_users, class_name: 'GitlabSubscriptions::UserAddOnAssignment', inverse_of: :add_on_purchase,
      dependent: :destroy # rubocop:disable Cop/ActiveRecordDependent -- legacy usage
    has_many :users, through: :assigned_users

    validates :add_on, :expires_on, presence: true
    validates :add_on, :started_at, presence: true
    validate :valid_namespace, if: :gitlab_com?
    validates :subscription_add_on_id, uniqueness: { scope: :namespace_id }
    validates :quantity,
      presence: true,
      numericality: { only_integer: true, greater_than_or_equal_to: 1 }
    validates :purchase_xid,
      presence: true,
      length: { maximum: 255 }

    scope :active, -> {
      today = Date.current

      where('started_at IS NULL OR started_at <= ?', today).where('? < expires_on', today)
    }
    scope :ready_for_cleanup, -> { where('expires_on < ?', CLEANUP_DELAY_PERIOD.ago.to_date) }
    scope :trial, -> { where(trial: true) }
    scope :by_add_on_name, ->(name) { joins(:add_on).where(add_on: { name: name }) }
    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
    scope :for_self_managed, -> { where(namespace: nil) }
    scope :for_gitlab_duo_pro, -> { where(subscription_add_on_id: AddOn.code_suggestions.pick(:id)) }
    scope :for_product_analytics, -> { where(subscription_add_on_id: AddOn.product_analytics.pick(:id)) }
    scope :for_duo_enterprise, -> { where(subscription_add_on_id: AddOn.duo_enterprise.pick(:id)) }
    # this executes 2 queries to the `AddOn` table, 1 for `code_suggestions` (duo pro), and 1 for `duo_enterprise`
    scope :for_duo_pro_or_duo_enterprise, -> { for_gitlab_duo_pro.or(for_duo_enterprise) }
    # this queries the `AddOn` table *once* for the duo add-ons (`code_suggestions` and `duo_enterprise`)
    scope :for_duo_add_ons, -> { where(subscription_add_on_id: AddOn.duo_add_ons.select(:id)) }
    scope :for_user, ->(user) { by_namespace(user.billable_gitlab_duo_pro_root_group_ids) }
    scope :assigned_to_user, ->(user) do
      active.joins(:assigned_users).merge(UserAddOnAssignment.by_user(user))
    end

    scope :requiring_assigned_users_refresh, ->(limit) do
      # Fetches add_on_purchases whose assigned_users have not been refreshed in last 8 hours.
      # Used primarily by BulkRefreshUserAssignmentsWorker, which is scheduled every 4 hours
      # by ScheduleBulkRefreshUserAssignmentsWorker.
      for_duo_pro_or_duo_enterprise
        .where("last_assigned_users_refreshed_at < ? OR last_assigned_users_refreshed_at is NULL", 8.hours.ago)
        .limit(limit)
    end

    delegate :name, to: :add_on, prefix: true, allow_nil: true

    def self.find_by_namespace_and_add_on(namespace, add_on)
      find_by(namespace: namespace, add_on: add_on)
    end

    def self.next_candidate_requiring_assigned_users_refresh
      requiring_assigned_users_refresh(1)
        .order('last_assigned_users_refreshed_at ASC NULLS FIRST')
        .lock('FOR UPDATE SKIP LOCKED')
        .includes(:namespace)
        .first
    end

    def self.uniq_add_on_names
      joins(:add_on).pluck(:name).uniq
    end

    def self.uniq_namespace_ids
      pluck(:namespace_id).compact.uniq
    end

    def self.maximum_duo_seat_count(namespace_ids: [])
      scope = active.for_duo_pro_or_duo_enterprise
      scope = scope.by_namespace(namespace_ids) if namespace_ids.any?
      scope.pluck(:quantity).max || 0
    end

    def already_assigned?(user)
      assigned_users.where(user: user).exists?
    end

    def active?
      today = Date.current

      (started_at.nil? || started_at <= today) && today < expires_on
    end

    def expired?
      expires_on <= Date.current
    end

    def delete_ineligible_user_assignments_in_batches!(batch_size: 50)
      deleted_assignments_count = 0

      assigned_users.each_batch(of: batch_size) do |batch|
        ineligible_user_ids = filter_ineligible_assigned_user_ids(batch.pluck_user_ids.to_set)
        deletable_assigned_users = batch.for_user_ids(ineligible_user_ids)
        count = deletable_assigned_users.count
        deleted_assignments_count += count

        log_ineligible_users_add_on_assignments_deletion(ineligible_user_ids) if count > 0

        # rubocop:disable Cop/DestroyAll -- callbacks required
        deletable_assigned_users.destroy_all
        # rubocop:enable Cop/DestroyAll

        cache_keys = ineligible_user_ids.map do |user_id|
          User.duo_pro_cache_key_formatted(user_id)
        end

        Gitlab::Instrumentation::RedisClusterValidator.allow_cross_slot_commands do
          Rails.cache.delete_multi(cache_keys)
        end
      end

      deleted_assignments_count
    end

    def lock_key_for_refreshing_user_assignments
      "#{self.class.name.underscore}:user_refresh:#{id}"
    end

    private

    def log_ineligible_users_add_on_assignments_deletion(user_ids)
      Gitlab::AppLogger.info(
        message: 'Ineligible UserAddOnAssignments destroyed',
        user_ids: user_ids.to_a,
        add_on: add_on.name,
        add_on_purchase: id,
        namespace: namespace&.path
      )
    end

    def filter_ineligible_assigned_user_ids(assigned_user_ids)
      return assigned_user_ids - saas_eligible_user_ids if namespace

      assigned_user_ids - self_managed_eligible_users_relation.where(id: assigned_user_ids).pluck(:id)
    end

    def saas_eligible_user_ids
      @eligible_user_ids ||= namespace.gitlab_duo_eligible_user_ids
    end

    def self_managed_eligible_users_relation
      @self_managed_eligible_users_relation ||= GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder.new(
        add_on_type: add_on_name.to_sym
      ).execute
    end

    def gitlab_com?
      ::Gitlab::CurrentSettings.should_check_namespace_plan?
    end

    def valid_namespace
      return if namespace.present? && namespace.root? && namespace.group_namespace?

      errors.add(:namespace, :invalid)
    end
  end
end
