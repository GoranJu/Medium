# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Registrations::CompanyHelper, feature_category: :onboarding do
  describe '#create_company_form_data' do
    let(:user) { build_stubbed(:user, onboarding_status_registration_type: 'trial') }
    let(:extra_params) do
      {
        role: '_params_role_',
        registration_objective: '_params_registration_objective_',
        jobs_to_be_done_other: '_params_jobs_to_be_done_other'
      }
    end

    let(:params) do
      ActionController::Parameters.new(extra_params)
    end

    before do
      allow(helper).to receive_messages(params: params, current_user: user)
    end

    it 'allows overriding data with params' do
      attributes = {
        submit_path: "/users/sign_up/company?#{extra_params.to_query}",
        first_name: user.first_name,
        last_name: user.last_name,
        email_domain: user.email_domain,
        form_type: 'registration',
        track_action_for_errors: 'trial_registration'
      }

      expect(helper.create_company_form_data(::Onboarding::StatusPresenter.new({}, {}, user))).to match(attributes)
    end
  end
end
