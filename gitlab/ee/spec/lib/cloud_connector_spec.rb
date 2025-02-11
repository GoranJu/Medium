# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::CloudConnector, feature_category: :cloud_connector do
  describe '.gitlab_realm' do
    subject { described_class.gitlab_realm }

    context 'when the current instance is gitlab.com', :saas do
      it { is_expected.to eq(described_class::GITLAB_REALM_SAAS) }
    end

    context 'when the current instance is not saas' do
      it { is_expected.to eq(described_class::GITLAB_REALM_SELF_MANAGED) }
    end
  end

  shared_examples 'building HTTP headers' do
    let(:expected_headers) do
      {
        'X-Gitlab-Host-Name' => Gitlab.config.gitlab.host,
        'X-Gitlab-Instance-Id' => an_instance_of(String),
        'X-Gitlab-Realm' => ::CloudConnector::GITLAB_REALM_SELF_MANAGED,
        'X-Gitlab-Version' => Gitlab.version_info.to_s
      }
    end

    subject(:headers) { described_class.headers(user) }

    context 'when the the user is present' do
      let(:user) { build(:user, id: 1) }

      it 'generates a hash with the required fields based on the user' do
        expect(headers).to match(expected_headers.merge('X-Gitlab-Global-User-Id' => an_instance_of(String)))
      end
    end

    context 'when the the user argument is nil' do
      let(:user) { nil }

      it 'generates a hash without `X-Gitlab-Global-User-Id`' do
        expect(headers).to match(expected_headers)
      end
    end
  end

  describe '.headers' do
    it_behaves_like 'building HTTP headers'
  end

  describe '.ai_headers' do
    let(:expected_headers) do
      super().merge(
        'X-Gitlab-Duo-Seat-Count' => '0',
        'X-Gitlab-Feature-Enabled-By-Namespace-Ids' => namespace_ids.join(',')
      )
    end

    let(:namespace_ids) { [1, 42] }

    it_behaves_like 'building HTTP headers'

    subject(:headers) { described_class.ai_headers(user, namespace_ids: namespace_ids) }

    context 'when Duo seats have been purchased' do
      let(:user) { nil }

      it 'sets the seat count header to the correct number of seats' do
        expect(GitlabSubscriptions::AddOnPurchase).to(
          receive(:maximum_duo_seat_count).with(namespace_ids: namespace_ids).and_return(5)
        )

        expect(headers).to include('X-Gitlab-Duo-Seat-Count' => '5')
      end
    end
  end

  describe '.self_managed_cloud_connected?' do
    subject(:self_managed_cloud_connected?) { described_class.self_managed_cloud_connected? }

    context 'when on saas' do
      it 'returns false' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(true)
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return('http::test.com')

        expect(self_managed_cloud_connected?).to be(false)
      end
    end

    context 'when self-hosted and cloud connected' do
      it 'returns true' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return(nil)

        expect(self_managed_cloud_connected?).to be(true)
      end
    end

    context 'when self-hosted and not cloud connected' do
      it 'returns false' do
        allow(::Gitlab).to receive(:org_or_com?).and_return(false)
        allow(::Gitlab::AiGateway).to receive(:self_hosted_url).and_return('http::test.com')

        expect(self_managed_cloud_connected?).to be(false)
      end
    end
  end
end
