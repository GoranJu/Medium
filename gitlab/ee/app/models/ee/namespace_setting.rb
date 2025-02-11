# frozen_string_literal: true

module EE
  module NamespaceSetting
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      DORMANT_REVIEW_PERIOD = 18.hours.ago

      cascading_attr :duo_features_enabled

      scope :requiring_dormant_member_review, ->(limit) do
        # look for settings that have not been reviewed in more than
        # 18 hours (catering for 6-hourly review schedule)
        where(remove_dormant_members: true)
          .where('last_dormant_member_review_at < ? OR last_dormant_member_review_at IS NULL', DORMANT_REVIEW_PERIOD)
          .limit(limit)
      end
      scope :duo_features_set, ->(setting) { where(duo_features_enabled: setting) }
      scope :order_by_last_dormant_member_review_asc, -> do
        order("last_dormant_member_review_at ASC NULLS FIRST")
      end

      belongs_to :default_compliance_framework, optional: true, class_name: "ComplianceManagement::Framework"

      validates :unique_project_download_limit,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10_000 },
        presence: true
      validates :unique_project_download_limit_interval_in_seconds,
        numericality: { only_integer: true, greater_than_or_equal_to: 0, less_than_or_equal_to: 10.days.to_i },
        presence: true
      validates :unique_project_download_limit_allowlist,
        length: { maximum: 100, message: ->(object, data) { _("exceeds maximum length (100 usernames)") } },
        allow_nil: false,
        user_existence: true,
        if: :unique_project_download_limit_allowlist_changed?
      validates :unique_project_download_limit_alertlist,
        length: { maximum: 100, message: ->(object, data) { _("exceeds maximum length (100 user ids)") } },
        allow_nil: false,
        user_id_existence: true,
        if: :unique_project_download_limit_alertlist_changed?
      validates :experiment_features_enabled, inclusion: { in: [true, false] }
      validates :new_user_signups_cap,
        numericality: { only_integer: true, greater_than_or_equal_to: 0 },
        if: -> { seat_control_user_cap? }

      validate :user_cap_allowed, if: -> { enabling_user_cap? }
      validate :experiment_features_allowed
      validates :remove_dormant_members, inclusion: { in: [false] }, if: :subgroup?
      validates :remove_dormant_members_period,
        numericality: { only_integer: true, greater_than_or_equal_to: 90, less_than_or_equal_to: 1827 } # 90d - ~5 years

      enum enterprise_users_extensions_marketplace_opt_in_status:
        ::Enums::WebIde::ExtensionsMarketplaceOptInStatus.statuses, _prefix: :enterprise_users_extensions_marketplace

      before_save :clear_new_user_signups_cap, unless: -> { seat_control_user_cap? }
      before_save :set_prevent_sharing_groups_outside_hierarchy
      after_save :disable_project_sharing!, if: -> { user_cap_enabled? || seat_control_block_overages? }

      delegate :root_ancestor, to: :namespace

      def enterprise_users_extensions_marketplace_enabled=(value)
        status = ActiveRecord::Type::Boolean.new.cast(value) ? 'enabled' : 'disabled'

        self.enterprise_users_extensions_marketplace_opt_in_status = status
      end

      def prevent_forking_outside_group?
        saml_setting = root_ancestor.saml_provider&.prohibited_outer_forks?

        return saml_setting unless namespace.feature_available?(:group_forking_protection)

        saml_setting || root_ancestor.namespace_settings&.prevent_forking_outside_group
      end

      # Define three instance methods:
      #
      # - [attribute]_of_parent_group         Returns the configuration value of the parent group
      # - [attribute]?(inherit_group_setting) Returns the final value after inheriting the parent group
      # - [attribute]_locked?                 Returns true if the value is inherited from the parent group
      def self.cascading_with_parent_namespace(attribute)
        define_method("#{attribute}_of_parent_group") do
          namespace&.parent&.namespace_settings&.public_send("#{attribute}?", inherit_group_setting: true)
        end

        define_method("#{attribute}?") do |inherit_group_setting: false|
          result = if inherit_group_setting
                     public_send(attribute.to_s) || public_send("#{attribute}_of_parent_group")
                   else
                     public_send(attribute.to_s)
                   end

          !!result
        end

        define_method("#{attribute}_locked?") do
          !!public_send("#{attribute}_of_parent_group")
        end
      end

      cascading_with_parent_namespace :only_allow_merge_if_pipeline_succeeds
      cascading_with_parent_namespace :allow_merge_on_skipped_pipeline
      cascading_with_parent_namespace :only_allow_merge_if_all_discussions_are_resolved
      cascading_with_parent_namespace :allow_merge_without_pipeline

      def unique_project_download_limit_alertlist
        self[:unique_project_download_limit_alertlist].presence || active_owner_ids
      end

      def experiment_settings_allowed?
        namespace.root?
      end

      def user_cap_enabled?
        seat_control_user_cap? && namespace.root?
      end

      def duo_availability
        if duo_features_enabled && !duo_features_enabled_locked?(include_self: true)
          :default_on
        elsif !duo_features_enabled && !duo_features_enabled_locked?(include_self: true)
          :default_off
        else
          :never_on
        end
      end

      def duo_availability=(value)
        if value == "default_on"
          self.duo_features_enabled = true
          self.lock_duo_features_enabled = false
        elsif value == "default_off"
          self.duo_features_enabled = false
          self.lock_duo_features_enabled = false
        else
          self.duo_features_enabled = false
          self.lock_duo_features_enabled = true
          self.experiment_features_enabled = false
        end
      end

      private

      def enabling_user_cap?
        return false unless persisted? && seat_control_changed?

        seat_control_user_cap?
      end

      def user_cap_allowed
        return if namespace.user_cap_available? && namespace.root? && !namespace.shared_externally?

        errors.add(:new_user_signups_cap, _("cannot be enabled"))
      end

      def clear_new_user_signups_cap
        self.new_user_signups_cap = nil
      end

      def set_prevent_sharing_groups_outside_hierarchy
        return unless user_cap_enabled? || namespace.block_seat_overages?

        self.prevent_sharing_groups_outside_hierarchy = true
      end

      def disable_project_sharing!
        namespace.update_attribute(:share_with_group_lock, true)
      end

      def active_owner_ids
        return [] unless namespace&.group_namespace?

        namespace.non_invite_owner_members.where(user: ::User.active).distinct(:user_id).pluck_user_ids
      end

      def experiment_features_allowed
        return unless experiment_features_enabled_changed?
        return if experiment_settings_allowed?

        errors.add(:experiment_features_enabled, _("Experiment features' settings not allowed."))
      end
    end

    class_methods do
      extend ::Gitlab::Utils::Override

      EE_NAMESPACE_SETTINGS_PARAMS = %i[
        unique_project_download_limit
        unique_project_download_limit_interval_in_seconds
        unique_project_download_limit_allowlist
        unique_project_download_limit_alertlist
        auto_ban_user_on_excessive_projects_download
        default_compliance_framework_id
        only_allow_merge_if_pipeline_succeeds
        allow_merge_without_pipeline
        allow_merge_on_skipped_pipeline
        only_allow_merge_if_all_discussions_are_resolved
        experiment_features_enabled
        service_access_tokens_expiration_enforced
        duo_features_enabled
        lock_duo_features_enabled
        enterprise_users_extensions_marketplace_opt_in_status
      ].freeze

      override :allowed_namespace_settings_params
      def allowed_namespace_settings_params
        super + EE_NAMESPACE_SETTINGS_PARAMS
      end
    end
  end
end
