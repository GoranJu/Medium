# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ExportMailer, feature_category: :dependency_management do
  include EmailSpec::Matchers

  describe '#completion_email' do
    # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need associations
    let_it_be(:export) { create(:dependency_list_export) }
    # rubocop:enable RSpec/FactoryBot/AvoidCreate

    subject(:email) { described_class.completion_email(export) }

    it 'creates an email notifying of export completion', :aggregate_failures do
      expect(email).to have_subject(s_('Dependencies|Dependency list export'))
      expect(email).to have_body_text('The dependency list was successfully exported for')
      expect(email).to have_body_text(export.project.full_name)
      expect(email).to have_body_text("/#{export.project.full_path}")
      expect(email).to have_body_text(%r{api/v4/dependency_list_exports/\d+/download})
      expect(email).to have_body_text(format(s_('Dependencies|This link will expire in %{number} days.'), number: 7))
      expect(email).to be_delivered_to([export.author.notification_email_for(export.project.group)])
    end
  end
end
