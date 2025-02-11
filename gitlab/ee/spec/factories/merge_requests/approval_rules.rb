# frozen_string_literal: true

FactoryBot.define do
  factory :merge_requests_approval_rule, class: 'MergeRequests::ApprovalRule' do
    sequence(:name) { |n| "Approval Rule #{n}" }
    approvals_required { 2 }
    rule_type { 0 }
    origin { 0 }

    trait :with_source_rule do
      association :source_rule, factory: :merge_requests_approval_rule
    end
  end
end
