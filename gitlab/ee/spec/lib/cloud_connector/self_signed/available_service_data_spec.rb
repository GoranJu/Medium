# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AvailableServiceData, feature_category: :cloud_connector do
  let(:cut_off_date) { 1.month.ago }
  let(:bundled_with) { {} }
  let(:backend) { 'gitlab-ai-gateway' }

  let_it_be(:rsa_key) { OpenSSL::PKey::RSA.new(2048) }
  let_it_be(:expected_key_data) { Rails.application.credentials.openid_connect_signing_key }

  subject(:available_service_data) { described_class.new(:duo_chat, cut_off_date, bundled_with, backend) }

  before do
    allow(OpenSSL::PKey::RSA).to receive(:new).with(expected_key_data).and_return(rsa_key)
  end

  describe '#access_token' do
    let(:resource) { create(:user) }
    let(:encoded_token_string) { 'token_string' }
    let(:dc_unit_primitives) { [:duo_chat_up1, :duo_chat_up2] }
    let(:duo_pro_scopes) { dc_unit_primitives + [:duo_chat_up3] }
    let(:duo_extra_scopes) { dc_unit_primitives + [:duo_chat_up4] }
    let(:bundled_with) { { "duo_pro" => duo_pro_scopes, "duo_extra" => duo_extra_scopes } }

    let(:issuer) { 'gitlab.com' }
    let(:instance_id) { 'instance-uuid' }
    let(:gitlab_realm) { 'saas' }
    let(:ttl) { 1.hour }
    let(:extra_claims) { {} }

    subject(:access_token) { available_service_data.access_token(resource) }

    shared_examples 'issue a token with scopes' do
      let(:expected_token) do
        instance_double('Gitlab::CloudConnector::JsonWebToken')
      end

      before do
        allow(Doorkeeper::OpenidConnect.configuration).to receive(:issuer).and_return(issuer)
        allow(Gitlab::CurrentSettings).to receive(:uuid).and_return(instance_id)
        allow(::CloudConnector).to receive(:gitlab_realm).and_return(gitlab_realm)
      end

      it 'returns the encoded token' do
        expect(Gitlab::CloudConnector::JsonWebToken).to receive(:new).with(
          issuer: issuer,
          audience: backend,
          subject: instance_id,
          realm: gitlab_realm,
          scopes: scopes,
          ttl: ttl,
          extra_claims: extra_claims
        ).and_return(expected_token)
        expect(expected_token).to receive(:encode).with(instance_of(::JWT::JWK::RSA)).and_return(encoded_token_string)

        expect(access_token).to eq(encoded_token_string)
      end

      it 'uses RFC 7638 thumbprint key generator to compute kid' do
        jwk = ::JWT::JWK.new(rsa_key, kid_generator: ::JWT::JWK::Thumbprint)
        _, token_header = *::JWT.decode(access_token, nil, false)

        actual_kid = token_header['kid']
        expected_kid = jwk.kid

        expect(actual_kid).to eq(expected_kid)
      end

      it 'does not repeatedly load the validation key' do
        expect(OpenSSL::PKey::RSA).to receive(:new)
          .with(expected_key_data)
          .at_most(:once)
          .and_return(rsa_key)

        3.times { described_class.new(:duo_chat, cut_off_date, bundled_with, backend).access_token }
      end
    end

    context 'when signing key is missing' do
      let(:fake_key_loader) do
        Class.new(described_class::CachingKeyLoader) do
          def self.signing_key
            load_signing_key # don't actually cache the key
          end
        end
      end

      before do
        stub_const(
          'CloudConnector::SelfSigned::AvailableServiceData::CachingKeyLoader',
          fake_key_loader
        )
        allow(Rails.application.credentials).to receive(:openid_connect_signing_key).and_return(nil)
      end

      it 'raises NoSigningKeyError' do
        expect { access_token }.to raise_error(StandardError, 'Cloud Connector: no key found')
      end
    end

    context 'with free access' do
      let(:cut_off_date) { nil }
      let(:scopes) { duo_pro_scopes | duo_extra_scopes }

      include_examples 'issue a token with scopes'
    end

    context 'when passing extra claims' do
      let(:extra_claims) { { custom: 123 } }
      let(:scopes) { duo_pro_scopes }

      subject(:access_token) { available_service_data.access_token(resource, extra_claims: extra_claims) }

      before do
        allow(available_service_data).to receive(:scopes_for).and_return(duo_pro_scopes)
      end

      include_examples 'issue a token with scopes'
    end

    context 'when passed resource is a User' do
      context 'with duo_pro purchased' do
        let(:scopes) { duo_pro_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names).and_return(%w[duo_pro])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with code_suggestions purchased' do
        let(:scopes) { duo_pro_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names)
            .and_return(%w[code_suggestions])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with duo_extra purchased' do
        let(:scopes) { duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names).and_return(%w[duo_extra])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with both duo_pro and duo_extra purchased' do
        let(:scopes) { duo_pro_scopes | duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases_assigned_to, :uniq_add_on_names)
            .and_return(%w[duo_pro duo_extra])
        end

        include_examples 'issue a token with scopes'
      end
    end

    context 'when passed resource is not a User' do
      let(:resource) { nil }

      context 'with duo_pro purchased' do
        let(:scopes) { duo_pro_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases, :uniq_add_on_names).and_return(%w[duo_pro])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with duo_extra purchased' do
        let(:scopes) { duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases, :uniq_add_on_names).and_return(%w[duo_extra])
        end

        include_examples 'issue a token with scopes'
      end

      context 'with both duo_pro and duo_extra purchased' do
        let(:scopes) { duo_pro_scopes | duo_extra_scopes }

        before do
          allow(available_service_data)
            .to receive_message_chain(:add_on_purchases, :uniq_add_on_names).and_return(%w[duo_pro duo_extra])
        end

        include_examples 'issue a token with scopes'
      end
    end
  end
end
