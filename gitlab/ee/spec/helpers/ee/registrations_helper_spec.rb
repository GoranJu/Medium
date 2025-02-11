# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::RegistrationsHelper, feature_category: :user_management do
  include Devise::Test::ControllerHelpers
  let(:expected_keys) { UserDetail.registration_objectives.keys - ['joining_team'] }

  describe '#shuffled_registration_objective_options' do
    subject(:shuffled_options) { helper.shuffled_registration_objective_options }

    it 'has values that match all UserDetail registration objective keys' do
      shuffled_option_values = shuffled_options.map { |item| item.last }

      expect(shuffled_option_values).to contain_exactly(*expected_keys)
    end

    it '"other" is always the last option' do
      expect(shuffled_options.last).to eq(['A different reason', 'other'])
    end
  end

  describe '#arkose_labs_data' do
    let(:request_double) { instance_double(ActionDispatch::Request) }
    let(:data_exchange_payload) { 'data_exchange_payload' }

    before do
      allow(helper).to receive(:request).and_return(request_double)

      allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_public_api_key).and_return('api-key')
      allow(::AntiAbuse::IdentityVerification::Settings).to receive(:arkose_labs_domain).and_return('domain')
      allow_next_instance_of(Arkose::DataExchangePayload, request_double,
        a_hash_including({ use_case: Arkose::DataExchangePayload::USE_CASE_SIGN_UP })) do |builder|
        allow(builder).to receive(:build).and_return(data_exchange_payload)
      end
    end

    subject(:data) { helper.arkose_labs_data }

    it 'contains the correct values' do
      expect(data).to eq({
        api_key: 'api-key',
        domain: 'domain',
        data_exchange_payload: data_exchange_payload,
        data_exchange_payload_path: data_exchange_payload_path
      })
    end

    context 'when fetch_arkose_data_exchange_payload feature flag is disabled' do
      it 'does not include data_exchange_payload_path' do
        stub_feature_flags(fetch_arkose_data_exchange_payload: false)

        expect(data.keys).not_to include(:data_exchange_payload_path)
      end
    end

    context 'when data exchange payload is nil' do
      let(:data_exchange_payload) { nil }

      it 'does not include data_exchange_payload' do
        expect(data.keys).not_to include(:data_exchange_payload)
      end
    end
  end

  describe '#display_password_requirements?' do
    subject(:display_password_requirements?) { helper.display_password_requirements? }

    context 'when password complexity feature is not available' do
      it { is_expected.to be(false) }
    end

    context 'when password complexity feature is available' do
      before do
        stub_licensed_features(password_complexity: true)
      end

      it { is_expected.to be(true) }
    end

    context 'when display_password_requirements is disabled' do
      before do
        stub_feature_flags(display_password_requirements: false)
      end

      context 'when password complexity feature is not available' do
        it { is_expected.to be(false) }
      end

      context 'when password complexity feature is available' do
        before do
          stub_licensed_features(password_complexity: true)
        end

        it { is_expected.to be(false) }
      end
    end
  end
end
