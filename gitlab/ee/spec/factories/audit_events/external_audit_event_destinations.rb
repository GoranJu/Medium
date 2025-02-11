# frozen_string_literal: true

FactoryBot.define do
  factory :external_audit_event_destination, class: 'AuditEvents::ExternalAuditEventDestination' do
    group
    sequence(:destination_url) { |n| "http://example.com/#{n}" }
    stream_destination_id { nil }
  end
end
