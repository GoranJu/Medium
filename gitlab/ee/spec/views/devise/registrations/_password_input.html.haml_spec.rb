# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'devise/registrations/_password_input', feature_category: :system_access do
  let(:display_password_requirements) { false }
  let(:minimum_password_length) { 8 }
  let(:password_length_hint) { "Minimum length is #{minimum_password_length} characters." }

  before do
    allow(view).to receive_messages(
      form: instance_double(Gitlab::FormBuilders::GitlabUiFormBuilder, label: '_label_'),
      form_resource_name: 'new_user',
      preregistration_tracking_label: '',
      display_password_requirements?: display_password_requirements
    )

    assign(:minimum_password_length, minimum_password_length)
  end

  it 'renders the password length hint' do
    render

    expect(rendered).to have_content(password_length_hint)
  end

  describe 'when displaying password requirements' do
    let(:display_password_requirements) { true }

    it 'does not render the password length hint' do
      render

      expect(rendered).not_to have_content(password_length_hint)
    end
  end
end
