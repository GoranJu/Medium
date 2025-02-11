# frozen_string_literal: true

FactoryBot.modify do
  factory :note do
    trait :on_epic do
      noteable { association(:epic) }
      project { nil }
    end

    trait :on_vulnerability do
      noteable { association(:vulnerability, project: project) }
    end

    trait :on_group_level_wiki do
      project { nil }
      namespace { association :group }
      noteable { association(:wiki_page_meta, namespace: namespace) }
    end
  end
end

FactoryBot.define do
  factory :note_on_epic, parent: :note, traits: [:on_epic]
  factory :note_on_vulnerability, parent: :note, traits: [:on_vulnerability]

  factory :discussion_note_on_vulnerability, parent: :note, traits: [:on_vulnerability], class: 'DiscussionNote'
end
