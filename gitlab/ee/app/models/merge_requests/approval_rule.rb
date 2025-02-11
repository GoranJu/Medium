# frozen_string_literal: true

module MergeRequests
  class ApprovalRule < ApplicationRecord
    self.table_name = 'merge_requests_approval_rules'

    validate :ensure_single_sharding_key

    with_options validate: true do
      enum :rule_type, { regular: 0, code_owner: 1, report_approver: 2, any_approver: 3 }, default: :regular
      enum :origin, { group: 0, project: 1, merge_request: 2 }, prefix: :originates_from
    end

    private

    def ensure_single_sharding_key
      return errors.add(:base, "Must have either `group_id` or `project_id`") if no_sharding_key?

      errors.add(:base, "Cannot have both `group_id` and `project_id`") if multiple_sharding_keys?
    end

    def sharding_keys
      [group_id, project_id]
    end

    def no_sharding_key?
      sharding_keys.all?(&:blank?)
    end

    def multiple_sharding_keys?
      sharding_keys.all?(&:present?)
    end
  end
end
