# frozen_string_literal: true

FactoryBot.define do
  factory :zoekt_node, class: '::Search::Zoekt::Node' do
    index_base_url { "http://#{SecureRandom.hex(4)}.example.com" }
    search_base_url { "http://#{SecureRandom.hex(4)}.example.com" }
    uuid { SecureRandom.uuid }
    last_seen_at { Time.zone.now }
    used_bytes { 10 }
    total_bytes { 100 }

    sequence(:metadata) do |n|
      { name: "zoekt-#{n}" }
    end

    trait :enough_free_space do
      total_bytes { 100_000_000 }
    end

    trait :offline do
      last_seen_at { (Search::Zoekt::Node::ONLINE_DURATION_THRESHOLD + 1.minute).ago }
    end

    trait :lost do
      last_seen_at { (Search::Zoekt::Node::LOST_DURATION_THRESHOLD + 1.minute).ago }
    end

    trait :not_enough_free_space do
      total_bytes { 100_000_000 }
      used_bytes { 90_000_000 }
    end
  end
end
