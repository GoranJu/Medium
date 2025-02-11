# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::TrialsHelper, feature_category: :acquisition do
  using RSpec::Parameterized::TableSyntax
  include Devise::Test::ControllerHelpers

  describe '#create_duo_pro_lead_form_data' do
    let(:user) { build_stubbed(:user, user_detail: build_stubbed(:user_detail, organization: '_org_')) }

    let(:extra_params) do
      {
        first_name: '_params_first_name_',
        last_name: '_params_last_name_',
        email_domain: 'example.org',
        company_name: '_params_company_name_',
        company_size: '_company_size_',
        phone_number: '1234',
        country: '_country_',
        state: '_state_'
      }
    end

    let(:params) { ActionController::Parameters.new(extra_params) }
    let(:eligible_namespaces) { [] }

    before do
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:current_user).and_return(user)
    end

    subject(:form_data) { helper.create_duo_pro_lead_form_data(eligible_namespaces) }

    it 'provides expected form data' do
      keys = extra_params.keys + [:submit_path, :submit_button_text]

      expect(form_data.keys.map(&:to_sym)).to match_array(keys)
    end

    it 'allows overriding data with params' do
      expect(form_data).to match(a_hash_including(extra_params))
    end

    context 'when namespace_id is in the params' do
      let(:extra_params) { { namespace_id: non_existing_record_id } }

      it 'provides the submit path with the namespace_id' do
        expect(form_data[:submit_path]).to eq(trials_duo_pro_path(step: :lead, **params.permit!))
      end
    end

    context 'when params are empty' do
      let(:extra_params) { {} }

      it 'uses the values from current user' do
        current_user_attributes = {
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.organization
        }

        expect(form_data).to match(a_hash_including(current_user_attributes))
      end
    end

    context 'when there are no eligible namespaces' do
      it 'has the Continue text' do
        expect(form_data).to match(a_hash_including(submit_button_text: s_('Trial|Continue')))
      end
    end

    context 'when there is a single eligible namespace' do
      let(:eligible_namespaces) { [build(:namespace)] }

      it 'has the Activate text' do
        expect(form_data).to match(a_hash_including(submit_button_text: s_('Trial|Activate my trial')))
      end
    end

    context 'when there are multiple eligible namespaces' do
      let(:eligible_namespaces) { build_list(:namespace, 2) }

      it 'has the Continue text' do
        expect(form_data).to match(a_hash_including(submit_button_text: s_('Trial|Continue')))
      end
    end
  end

  describe '#create_duo_enterprise_lead_form_data' do
    let(:user) { build_stubbed(:user, user_detail: build_stubbed(:user_detail, organization: '_org_')) }

    let(:extra_params) do
      {
        first_name: '_params_first_name_',
        last_name: '_params_last_name_',
        email_domain: 'example.org',
        company_name: '_params_company_name_',
        company_size: '_company_size_',
        phone_number: '1234',
        country: '_country_',
        state: '_state_'
      }
    end

    let(:params) { ActionController::Parameters.new(extra_params) }
    let(:eligible_namespaces) { [] }

    before do
      allow(helper).to receive(:params).and_return(params)
      allow(helper).to receive(:current_user).and_return(user)
    end

    subject(:form_data) { helper.create_duo_enterprise_lead_form_data(eligible_namespaces) }

    it 'provides expected form data' do
      keys = extra_params.keys + [:submit_path, :submit_button_text]

      expect(form_data.keys.map(&:to_sym)).to match_array(keys)
    end

    it 'allows overriding data with params' do
      expect(form_data).to match(a_hash_including(extra_params))
    end

    context 'when namespace_id is in the params' do
      let(:extra_params) { { namespace_id: non_existing_record_id } }

      it 'provides the submit path with the namespace_id' do
        expect(form_data[:submit_path]).to eq(trials_duo_enterprise_path(step: :lead, **params.permit!))
      end
    end

    context 'when params are empty' do
      let(:extra_params) { {} }

      it 'uses the values from current user' do
        current_user_attributes = {
          first_name: user.first_name,
          last_name: user.last_name,
          company_name: user.organization
        }

        expect(form_data).to match(a_hash_including(current_user_attributes))
      end
    end

    context 'when there are no eligible namespaces' do
      it 'has the Continue text' do
        expect(form_data).to match(a_hash_including(submit_button_text: s_('Trial|Continue')))
      end
    end

    context 'when there is a single eligible namespace' do
      let(:eligible_namespaces) { [build(:namespace)] }

      it 'has the Activate text' do
        expect(form_data).to match(a_hash_including(submit_button_text: s_('Trial|Activate my trial')))
      end
    end

    context 'when there are multiple eligible namespaces' do
      let(:eligible_namespaces) { build_list(:namespace, 2) }

      it 'has the Continue text' do
        expect(form_data).to match(a_hash_including(submit_button_text: s_('Trial|Continue')))
      end
    end
  end

  describe '#show_tier_badge_for_new_trial?' do
    where(:trials_available?, :paid?, :private?, :never_had_trial?, :authorized, :result) do
      false | false | true | true | true | false
      true | true | true | true | true | false
      true | false | false | true | true | false
      true | false | true | false | true | false
      true | false | true | true | false | false
      true | false | true | true | true | true
    end

    with_them do
      let(:namespace) { build(:namespace) }
      let(:user) { build(:user) }

      before do
        stub_saas_features(subscriptions_trials: trials_available?)
        allow(namespace).to receive(:paid?).and_return(paid?)
        allow(namespace).to receive(:private?).and_return(private?)
        allow(namespace).to receive(:never_had_trial?).and_return(never_had_trial?)
        allow(helper).to receive(:can?).with(user, :read_billing, namespace).and_return(authorized)
      end

      subject { helper.show_tier_badge_for_new_trial?(namespace, user) }

      it { is_expected.to be(result) }
    end
  end

  describe '#glm_source' do
    let(:host) { ::Gitlab.config.gitlab.host }

    it 'return gitlab config host' do
      glm_source = helper.glm_source

      expect(glm_source).to eq(host)
    end
  end

  describe '#duo_trial_namespace_selector_data' do
    let(:parsed_selector_data) { Gitlab::Json.parse(selector_data[:items]) }

    subject(:selector_data) { helper.duo_trial_namespace_selector_data(eligible_namespaces, nil) }

    context 'when there are eligible namespaces' do
      let(:namespace) { build(:namespace) }
      let(:eligible_namespaces) { [namespace] }

      it 'returns selector data with the eligible namespace' do
        is_expected.to include(any_trial_eligible_namespaces: 'true')
        expect(parsed_selector_data).to eq([{ 'text' => namespace.name, 'value' => namespace.id.to_s }])
      end
    end

    context 'when there are no eligible namespaces' do
      let(:eligible_namespaces) { [] }

      it 'returns empty selector data' do
        is_expected.to include(any_trial_eligible_namespaces: 'false')
        expect(parsed_selector_data).to be_empty
      end
    end
  end

  describe '#trial_form_errors_message' do
    let(:result) { ServiceResponse.error(message: ['some error']) }

    subject { helper.trial_form_errors_message(result) }

    it 'returns error message from the result directly' do
      is_expected.to eq('some error')
    end

    context 'when the error has :generic_trial_error as reason' do
      let(:message) { ['Some Error 1', 'Some Error 2'] }
      let(:link) { '<a target="_blank" rel="noopener noreferrer" href="https://support.gitlab.com">GitLab Support</a>' }

      let(:result) do
        ServiceResponse.error(message: message,
          reason: GitlabSubscriptions::Trials::BaseApplyTrialService::GENERIC_TRIAL_ERROR)
      end

      it 'displays the error message and a support message' do
        is_expected.to eq("Please reach out to #{link} for assistance: Some Error 1 and Some Error 2.")
      end

      context 'without message' do
        let(:message) { [] }

        it 'displays only a support message' do
          is_expected.to eq("Please reach out to #{link} for assistance.")
        end
      end
    end
  end
end
