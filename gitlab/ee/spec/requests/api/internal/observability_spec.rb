# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Observability, :cloud_licenses, feature_category: :shared do
  include WorkhorseHelpers

  using RSpec::Parameterized::TableSyntax

  let(:plan) { License::ULTIMATE_PLAN }
  let(:license) { build(:license, plan: plan) }
  let(:instance_uuid) { "uuid-not-set" }
  let(:global_user_id) { "user-id" }
  let(:hostname) { "localhost" }
  let(:correlation_id) { 'my-correlation-id' }
  let(:backend) { 'http://gob.local' }

  let_it_be(:namespace) { create(:group) }
  let_it_be(:group) { create(:group, parent: namespace) }
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:gob_token) { 'generated-jwt' }

  before do
    stub_licensed_features(observability: true)

    allow(License).to receive(:current).and_return(license)
    allow(Gitlab::GlobalAnonymousId).to receive(:user_id).and_return(global_user_id)
    allow(Gitlab::GlobalAnonymousId).to receive(:instance_id).and_return(instance_uuid)
    allow(Labkit::Correlation::CorrelationId).to receive(:current_or_new_id).and_return(correlation_id)
    allow(Gitlab::Observability).to receive(:observability_url).and_return(backend)
    allow(Gitlab::Observability).to receive(:observability_ingest_url).and_return(backend)
  end

  def expect_status(status)
    subject
    expect(response).to have_gitlab_http_status(status)
  end

  shared_examples 'success' do
    it 'returns 200 with expected json' do
      expect_status(:success)
      expect(json_response).to eq('gob' => {
        'backend' => backend,
        'headers' => {
          'X-GitLab-Namespace-id' => namespace.id.to_s,
          'X-GitLab-Project-id' => project.id.to_s,
          'Authorization' => "Bearer #{gob_token}",
          'X-Request-ID' => correlation_id,
          'X-Gitlab-Host-Name' => hostname,
          'X-Gitlab-Instance-Id' => instance_uuid,
          'X-Gitlab-Realm' => gitlab_realm,
          'X-Gitlab-Version' => Gitlab.version_info.to_s,
          'X-Gitlab-Global-User-Id' => global_user_id
        }
      })
    end
  end

  where(:endpoint, :req_method, :sufficient_role, :insufficient_role) do
    '/read/analytics'  | 'GET'   | :reporter   | :guest
    '/read/traces'     | 'GET'   | :reporter   | :guest
    '/read/services'   | 'GET'   | :reporter   | :guest
    '/read/metrics'    | 'GET'   | :reporter   | :guest
    '/read/logs'       | 'GET'   | :reporter   | :guest
    '/write/traces'    | 'POST'  | :developer  | :reporter
    '/write/metrics'   | 'POST'  | :developer  | :reporter
    '/write/logs'      | 'POST'  | :developer  | :reporter
  end

  with_them do
    describe 'endpoint', :with_cloud_connector do
      let(:headers) { workhorse_internal_api_request_header }
      let(:gitlab_realm) { 'self-managed' }
      let(:pat) { nil }

      def full_path
        "/internal/observability/project/#{project.id}#{endpoint}"
      end

      subject(:request) do
        case req_method
        when 'GET'
          get(api(full_path, personal_access_token: pat), headers: headers)
        when 'POST'
          post(api(full_path, personal_access_token: pat), headers: headers)
        end
      end

      before do
        login_as(user)
        create(:project_member, sufficient_role, user: user, project: project)
        service_data = CloudConnector::SelfManaged::AvailableServiceData.new(:observability_all, nil, nil)
        allow(CloudConnector::AvailableServices).to receive(:find_by_name)
                                                      .with(:observability_all)
                                                      .and_return(service_data)
        allow(service_data).to receive(:access_token).with(namespace,
          { extra_claims: { gitlab_namespace_id: namespace.id.to_s } }).and_return(gob_token)
      end

      it_behaves_like 'success'

      context 'without workhorse internal header' do
        let(:headers) { {} }

        it { expect_status(:forbidden) }
      end

      context 'with personal access token' do
        let(:pat) { create(:personal_access_token, user: user) }

        before do
          logout(:user)
        end

        it_behaves_like 'success'
      end

      context 'with a resource access token' do
        let(:project_bot_user) { create(:user, :project_bot) }
        let(:pat) do
          create(:personal_access_token, user: project_bot_user)
        end

        before do
          logout(:user)
          create(:project_member, sufficient_role, user: project_bot_user, project: project)
        end

        it_behaves_like 'success'

        it 'uses the correct url based on the request method' do
          if req_method.eql?('GET')
            expect(Gitlab::Observability).to receive(:observability_url)
          else
            expect(Gitlab::Observability).to receive(:observability_ingest_url)
          end

          request
        end
      end

      context 'without a logged in user' do
        before do
          logout(:user)
        end

        it { expect_status(:unauthorized) }
      end

      context 'without minimum role' do
        let(:user2) { create(:user) }

        before do
          logout(:user)
          login_as(user2)
          create(:project_member, insufficient_role, user: user2, project: project)
        end

        it { expect_status(:not_found) }
      end

      context 'when the licensed feature is not available' do
        before do
          stub_licensed_features(observability: false)
        end

        it { expect_status(:not_found) }
      end

      context 'when the feature flag is disabled' do
        before do
          stub_feature_flags(observability_features: false)
          stub_feature_flags(observability_tracing: false)
        end

        it { expect_status(:not_found) }
      end
    end
  end
end
