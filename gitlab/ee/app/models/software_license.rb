# frozen_string_literal: true

# This class represents a software license.
# For use in the License Management feature.
class SoftwareLicense < ApplicationRecord
  include Presentable

  TransactionInProgressError = Class.new(StandardError)
  ALL_LICENSE_NAMES_CACHE_KEY = [name, 'all_license_names'].freeze
  TRANSACTION_MESSAGE = "Sub-transactions are not allowed as there is already an open transaction."
  LICENSE_LIMIT = 1_000

  validates :name, presence: true, uniqueness: true
  validates :spdx_identifier, length: { maximum: 255 }

  scope :by_name, ->(names) { where(name: names) }
  scope :by_spdx, ->(spdx_identifier) { where(spdx_identifier: spdx_identifier) }
  scope :ordered, -> { order(:name) }
  scope :spdx, -> { where.not(spdx_identifier: nil) }
  scope :unknown, -> { where(spdx_identifier: nil) }
  scope :grouped_by_name, -> { group(:name) }
  scope :unreachable_limit, -> { limit(LICENSE_LIMIT) }

  class << self
    def all_license_names
      Rails.cache.fetch(ALL_LICENSE_NAMES_CACHE_KEY, expires_in: 7.days) do
        spdx.ordered.unreachable_limit.pluck_names
      end
    end

    def pluck_names
      pluck(:name)
    end

    # This method can be used when called within a transaction.
    # For example from Security::ProcessScanResultPolicyWorker.
    # To avoid sub transactions the method does not call `safe_find_or_create_by!`.
    def unsafe_create_policy_for!(
      project:, name:, classification:,
      scan_result_policy_read: nil,
      approval_policy_rule_id: nil,
      custom_software_license: nil
    )

      catalogue_license = Gitlab::SPDX::Catalogue.latest_active_licenses.find { |license| license.name == name }

      project.software_license_policies.create!(
        classification: classification,
        software_license: find_or_create_by!(name: name),
        scan_result_policy_read: scan_result_policy_read,
        approval_policy_rule_id: approval_policy_rule_id,
        custom_software_license: custom_software_license,
        software_license_spdx_identifier: catalogue_license&.id
      )
    end
  end

  def canonical_id
    spdx_identifier || name.downcase
  end
end
