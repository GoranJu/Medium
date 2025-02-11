# frozen_string_literal: true

# This class represents a software license policy. Which means the fact that the user
# approves or not of the use of a certain software license in their project.
# For use in the License Management feature.
class SoftwareLicensePolicy < ApplicationRecord
  include Presentable
  include EachBatch
  include FromUnion

  # Only allows modification of the approval status
  FORM_EDITABLE = %i[approval_status].freeze

  belongs_to :project, inverse_of: :software_license_policies
  belongs_to :software_license, -> { readonly }
  belongs_to :custom_software_license, class_name: 'Security::CustomSoftwareLicense'
  belongs_to :scan_result_policy_read,
    class_name: 'Security::ScanResultPolicyRead',
    foreign_key: 'scan_result_policy_id',
    optional: true

  belongs_to :approval_policy_rule, class_name: 'Security::ApprovalPolicyRule', optional: true

  attr_readonly :software_license, :custom_software_license

  enum classification: {
    denied: 0,
    allowed: 1
  }
  validates_presence_of :project
  validates :classification, presence: true

  validates :software_license, presence: true, unless: :custom_software_license
  validates :custom_software_license, presence: true, unless: :software_license

  # A license is unique for its project since it can't be approved and denied.
  validates :software_license, uniqueness: { scope: [:project_id, :scan_result_policy_id] }, allow_blank: true
  validates :custom_software_license, uniqueness: { scope: [:project_id, :scan_result_policy_id] }, allow_blank: true
  validates :software_license_spdx_identifier, length: { maximum: 255 }

  scope :for_project, ->(project) { where(project: project) }
  scope :for_scan_result_policy_read, ->(scan_result_policy_id) { where(scan_result_policy_id: scan_result_policy_id) }
  scope :with_license, -> { joins(:software_license) }
  scope :including_license, -> { includes(:software_license) }
  scope :including_custom_license, -> { includes(:custom_software_license) }
  scope :including_scan_result_policy_read, -> { includes(:scan_result_policy_read) }
  scope :unreachable_limit, -> { limit(1_000) }
  scope :with_scan_result_policy_read, -> { where.not(scan_result_policy_id: nil) }

  scope :exclusion_allowed, -> do
    joins(:scan_result_policy_read)
      .where(scan_result_policy_read: { match_on_inclusion_license: false })
  end

  scope :with_license_by_name, ->(license_name) do
    if Feature.enabled?(:static_licenses) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- This FF is all or nothing
      license_names = Array.wrap(license_name).map(&:downcase)
      related_spdx_identifiers = latest_active_licenses_by_name(license_names).map(&:id)
      where(software_license_spdx_identifier: related_spdx_identifiers)
    else
      with_license.where(SoftwareLicense.arel_table[:name].lower.in(Array(license_name).map(&:downcase)))
    end
  end

  scope :with_license_or_custom_license_by_name, ->(license_names) do
    license_names = Array(license_names).map(&:downcase)

    software_licenses = joins(:software_license)
      .where(SoftwareLicense.arel_table[:name].lower.in(license_names))

    custom_software_licenses = joins(:custom_software_license)
      .where(Security::CustomSoftwareLicense.arel_table[:name].lower.in(license_names))

    SoftwareLicensePolicy.from_union([software_licenses, custom_software_licenses])
  end

  scope :by_spdx, ->(spdx_identifier) do
    if Feature.enabled?(:static_licenses) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
      where(software_license_spdx_identifier: spdx_identifier)
    else
      with_license.where(software_licenses: { spdx_identifier: spdx_identifier })
    end
  end

  def self.approval_status_values
    %w[allowed denied]
  end

  def self.latest_active_licenses
    Gitlab::SPDX::Catalogue.latest_active_licenses
  end

  def self.latest_active_licenses_by_name(license_names)
    latest_active_licenses.select do |license|
      license.name.downcase.in?(license_names)
    end
  end

  def self.latest_active_licenses_by_spdx(spdx_identifier)
    latest_active_licenses.select { |license| license.id == spdx_identifier }
  end

  def approval_status
    classification
  end

  def name
    if Feature.enabled?(:static_licenses) && software_license_spdx_identifier # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
      self.class.latest_active_licenses_by_spdx(software_license_spdx_identifier)&.first&.name
    elsif Feature.enabled?(:custom_software_license, project) && custom_software_license
      custom_software_license&.name
    else
      software_license&.name
    end
  end

  def spdx_identifier
    if Feature.enabled?(:static_licenses) && software_license_spdx_identifier # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global
      software_license_spdx_identifier
    else
      software_license&.spdx_identifier
    end
  end
end
