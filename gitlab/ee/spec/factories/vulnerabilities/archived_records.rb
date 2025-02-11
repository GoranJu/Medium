# frozen_string_literal: true

FactoryBot.define do
  factory :vulnerability_archived_record, class: 'Vulnerabilities::ArchivedRecord' do
    project
    archive factory: :vulnerability_archive
    sequence(:vulnerability_identifier)
    data { {} }
  end
end
