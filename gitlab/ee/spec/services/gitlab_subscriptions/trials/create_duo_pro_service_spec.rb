# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateDuoProService, feature_category: :plan_provisioning do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user, preferred_language: 'en') }
  let(:step) { described_class::LEAD }

  describe '#execute', :saas do
    let(:trial_params) { {} }
    let(:extra_lead_params) { {} }
    let(:trial_user_params) do
      { trial_user: lead_params(user, extra_lead_params).merge({ add_on_name: 'code_suggestions' }) }
    end

    let(:lead_service_class) { GitlabSubscriptions::Trials::CreateAddOnLeadService }
    let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyDuoProService }
    let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

    before_all do
      create(:gitlab_subscription_add_on, :gitlab_duo_pro)
    end

    subject(:execute) do
      described_class.new(
        step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
      ).execute
    end

    it_behaves_like 'when on the lead step', :premium_plan
    it_behaves_like 'when on trial step', :premium_plan
    it_behaves_like 'with an unknown step'
    it_behaves_like 'with no step'

    it_behaves_like 'for tracking the lead step', :premium_plan, 'duo_pro_'
    it_behaves_like 'for tracking the trial step', :premium_plan, 'duo_pro_'

    it_behaves_like 'creating add-on when namespace_id is provided', :premium_plan, :ultimate_plan
  end

  context 'when pass_add_on_name_for_trial_requests is disabled' do
    before do
      stub_feature_flags(pass_add_on_name_for_trial_requests: false)
    end

    describe '#execute', :saas do
      let(:trial_params) { {} }
      let(:extra_lead_params) { {} }
      let(:trial_user_params) do
        { trial_user: lead_params(user, extra_lead_params) }
      end

      let(:lead_service_class) { GitlabSubscriptions::Trials::CreateAddOnLeadService }
      let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyDuoProService }
      let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

      before_all do
        create(:gitlab_subscription_add_on, :gitlab_duo_pro)
      end

      subject(:execute) do
        described_class.new(
          step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
        ).execute
      end

      it_behaves_like 'when on the lead step', :premium_plan
      it_behaves_like 'when on trial step', :premium_plan
      it_behaves_like 'with an unknown step'
      it_behaves_like 'with no step'

      it_behaves_like 'for tracking the lead step', :premium_plan, 'duo_pro_'
      it_behaves_like 'for tracking the trial step', :premium_plan, 'duo_pro_'

      it_behaves_like 'creating add-on when namespace_id is provided', :premium_plan, :ultimate_plan
    end
  end

  def lead_params(user, extra_lead_params)
    {
      company_name: 'GitLab',
      company_size: '1-99',
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: '+1 23 456-78-90',
      country: 'US',
      work_email: user.email,
      uid: user.id,
      setup_for_company: user.setup_for_company,
      skip_email_confirmation: true,
      gitlab_com_trial: true,
      provider: 'gitlab',
      product_interaction: 'duo_pro_trial',
      preferred_language: 'English',
      opt_in: user.onboarding_status_email_opt_in
    }.merge(extra_lead_params)
  end
end
