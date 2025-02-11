# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_task, class: '::Search::Zoekt::Task' do
    node { association(:zoekt_node) }
    zoekt_repository { association(:zoekt_repository) }
    project_identifier { zoekt_repository.project.id }
    task_type { :index_repo }

    trait :done do
      state { :done }
    end

    trait :failed do
      state { :failed }
    end

    trait :pending do
      state { :pending }
    end

    trait :processing do
      state { :processing }
    end

    trait :orphaned do
      state { :orphaned }
    end
  end
end
