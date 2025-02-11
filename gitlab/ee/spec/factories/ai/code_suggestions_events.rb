# frozen_string_literal: true

FactoryBot.define do
  factory :code_suggestion_event, class: '::Ai::CodeSuggestionEvent' do
    event { 'code_suggestion_shown_in_ide' }
    user { build_stubbed(:user, :with_namespace) }
    payload { { language: 'ruby', suggestion_size: 1, unique_tracking_id: SecureRandom.hex.slice(0, 20) } }

    initialize_with { new({}) }

    trait :shown do
      event { 'code_suggestion_shown_in_ide' }
    end

    trait :accepted do
      event { 'code_suggestion_accepted_in_ide' }
    end

    trait :rejected do
      event { 'code_suggestion_rejected_in_ide' }
    end
  end
end
