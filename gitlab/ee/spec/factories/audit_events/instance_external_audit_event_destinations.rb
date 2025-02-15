# frozen_string_literal: true

FactoryBot.define do
  factory :instance_external_audit_event_destination, class: 'AuditEvents::InstanceExternalAuditEventDestination' do
    sequence(:destination_url) { |n| "http://example.com/#{n}" }
    stream_destination_id { nil }
  end
end
