# frozen_string_literal: true

class MemberRole < ApplicationRecord # rubocop:disable Gitlab/NamespacedClass
  include GitlabSubscriptions::SubscriptionHelper

  MAX_COUNT_PER_GROUP_HIERARCHY = 10

  # base_access_level is validated against this array,
  # so a migration may be needed if you change it
  LEVELS = ::Gitlab::Access.options_for_custom_roles.values.freeze

  has_many :members
  has_many :saml_providers
  has_many :saml_group_links
  has_many :group_group_links
  has_many :project_group_links
  has_many :users, -> { distinct }, through: :members
  has_many :user_member_roles, class_name: 'Users::UserMemberRole'
  belongs_to :namespace

  validates :name, presence: true
  validates :name, uniqueness: { scope: :namespace_id }
  validates :base_access_level, presence: true, inclusion: { in: LEVELS }, unless: :admin_related_role?
  validates :permissions, json_schema: { filename: 'member_role_permissions' }
  validates :namespace, presence: true, if: :gitlab_com_subscription?
  validates :namespace, absence: true, if: :admin_related_role?

  validate :belongs_to_top_level_namespace
  validate :max_count_per_group_hierarchy, on: :create
  validate :validate_namespace_locked, on: :update
  validate :base_access_level_locked, on: :update
  validate :validate_requirements
  validate :ensure_at_least_one_permission_is_enabled

  before_save :set_occupies_seat

  scope :elevating, -> do
    return none if elevating_permissions.empty?

    first_permission, *other_permissions = elevating_permissions

    scope = permissions_where(first_permission => true)
    other_permissions.each do |permission|
      scope = scope.or(permissions_where(permission => true))
    end

    scope
  end

  scope :occupies_seat, -> { where(occupies_seat: true) }

  scope :by_namespace, ->(group_ids) { where(namespace_id: group_ids) }
  scope :for_instance, -> { where(namespace_id: nil) }
  scope :non_admin, -> { where.not(base_access_level: nil) }
  scope :admin, -> { where(base_access_level: nil) }

  scope :with_members_count, -> do
    left_outer_joins(:members)
      .group(:id)
      .select(MemberRole.default_select_columns)
      .select('COUNT(members.id) AS members_count')
  end

  scope :with_users_count, -> do
    left_outer_joins(:members)
      .group(:id)
      .select(MemberRole.default_select_columns)
      .select('COUNT(DISTINCT members.user_id) AS users_count')
  end

  before_destroy :prevent_delete_after_member_associated

  jsonb_accessor :permissions, Gitlab::CustomRoles::Definition.all.keys.index_with(:boolean)

  self.filter_attributes = [] # There are no secrets stored in this model, prevent filtering of attributes

  def self.levels_sentence
    ::Gitlab::Access
      .options_with_owner
      .map { |name, value| "#{value} (#{name})" }
      .to_sentence
  end

  def self.declarative_policy_class
    'Members::MemberRolePolicy'
  end

  class << self
    def elevating_permissions
      MemberRole.all_customizable_permissions.reject { |_k, v| v[:skip_seat_consumption] }.keys
    end

    def all_customizable_permissions
      Gitlab::CustomRoles::Definition.all
    end

    def all_customizable_standard_permissions
      Gitlab::CustomRoles::Definition.standard
    end

    def all_customizable_admin_permissions
      Gitlab::CustomRoles::Definition.admin
    end

    def all_customizable_project_permissions
      MemberRole.all_customizable_standard_permissions.select { |_k, v| v[:project_ability] }.keys
    end

    def all_customizable_group_permissions
      MemberRole.all_customizable_standard_permissions.select { |_k, v| v[:group_ability] }.keys
    end

    def all_customizable_admin_permission_keys
      Gitlab::CustomRoles::Definition.admin.keys
    end

    def customizable_permissions_exempt_from_consuming_seat
      MemberRole.all_customizable_permissions.select { |_k, v| v[:skip_seat_consumption] }.keys
    end

    def permission_enabled?(permission, user = nil)
      return true unless ::Feature::Definition.get("custom_ability_#{permission}")

      ::Feature.enabled?("custom_ability_#{permission}", user)
    end
  end

  def enabled_permission_items
    MemberRole.all_customizable_permissions.filter do |permission|
      attributes[permission.to_s] && self.class.permission_enabled?(permission)
    end
  end

  def enabled_permissions
    enabled_permission_items.keys
  end

  def dependent_security_policies
    return Security::Policy.none if security_policies_disabled?

    policies = Security::Policy.for_custom_role(id)
    return policies unless gitlab_com_subscription?

    policies.for_policy_configuration(namespace.all_descendant_security_orchestration_policy_configurations)
  end

  def admin_related_role?
    admin_related_permissions.present? && admin_related_permissions.all? do |permission|
      self.class.permission_enabled?(permission)
    end
  end

  private

  def security_policies_disabled?
    return !namespace.licensed_feature_available?(:security_orchestration_policies) if gitlab_com_subscription?

    !License.feature_available?(:security_orchestration_policies)
  end

  def admin_related_permissions
    self.class.all_customizable_admin_permission_keys & enabled_permissions
  end

  def belongs_to_top_level_namespace
    return if !namespace || namespace.root?

    errors.add(:namespace, s_("MemberRole|must be top-level namespace"))
  end

  def max_count_per_group_hierarchy
    return unless namespace
    return if namespace.member_roles.count < MAX_COUNT_PER_GROUP_HIERARCHY

    errors.add(
      :namespace,
      s_(
        "MemberRole|maximum number of Member Roles are already in use by the group hierarchy. " \
        "Please delete an existing Member Role."
      )
    )
  end

  def validate_namespace_locked
    return unless namespace_id_changed?

    errors.add(:namespace, s_("MemberRole|can't be changed"))
  end

  def validate_requirements
    self.class.all_customizable_permissions.each do |permission, params|
      requirements = params[:requirements]

      next unless self[permission] # skipping permissions not set for the object
      next unless requirements.present? # skipping permissions that have no requirements

      requirements.each do |requirement|
        available_from = self.class.all_customizable_permissions[requirement.to_sym][:available_from_access_level]
        next if available_from && base_access_level >= available_from
        next if self[requirement] # the requirement is met

        errors.add(:base,
          format(s_("MemberRole|%{requirement} has to be enabled in order to enable %{permission}"),
            requirement: requirement.to_s.humanize, permission: permission.to_s.humanize)
        )
      end
    end
  end

  def ensure_at_least_one_permission_is_enabled
    return if self.class.all_customizable_permissions.keys.any? { |attr| self[attr] }

    errors.add(:base, s_('MemberRole|Cannot create a member role with no enabled permissions'))
  end

  def base_access_level_locked
    return unless changed_attributes.include?('base_access_level')

    errors.add(
      :base_access_level,
      s_('MemberRole|cannot be changed. Please create a new Member Role instead.')
    )
  end

  def prevent_delete_after_member_associated
    return unless members.present?

    errors.add(
      :base,
      s_(
        "MemberRole|Role is assigned to one or more group members. " \
        "Remove role from all group members, then delete role."
      )
    )

    throw :abort # rubocop:disable Cop/BanCatchThrow
  end

  def set_occupies_seat
    return true if base_access_level.nil?

    self.occupies_seat = base_access_level > Gitlab::Access::GUEST ||
      self.class.elevating_permissions.any? { |attr| self[attr] }
  end
end
