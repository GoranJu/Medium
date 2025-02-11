# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::UpcomingReconciliations, :aggregate_failures, :api, feature_category: :subscription_management do
  include GitlabSubscriptions::InternalApiHelpers

  before do
    stub_saas_features(gitlab_com_subscriptions: true)
    stub_application_setting(check_namespace_plan: true)
  end

  def upcoming_reconciliations_path(namespace_id)
    internal_api("namespaces/#{namespace_id}/upcoming_reconciliations")
  end

  describe 'PUT /internal/gitlab_subscriptions/namespaces/:namespace_id/upcoming_reconciliations' do
    let_it_be(:namespace) { create(:group) }

    context 'when unauthenticated' do
      it 'returns authentication error' do
        put upcoming_reconciliations_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when supplied with valid params' do
        context 'when upcoming reconciliation does not exist for namespace' do
          it 'creates new upcoming reconciliation' do
            params = {
              next_reconciliation_date: Date.today + 5.days,
              display_alert_from: Date.today - 2.days
            }

            expect { put upcoming_reconciliations_path(namespace.id), headers: internal_api_headers, params: params }
              .to change { namespace.reload.upcoming_reconciliation }.from(nil).to be_present

            expect(response).to have_gitlab_http_status(:ok)
          end
        end

        context 'when upcoming reconciliation exists for namespace' do
          it 'updates the existing upcoming reconciliation' do
            create(:upcoming_reconciliation, :saas, namespace: namespace)

            expected_next_reconciliation_date = Date.today + 5.days
            expected_display_alert_from_date = Date.today + 2.days

            params = {
              next_reconciliation_date: expected_next_reconciliation_date,
              display_alert_from: expected_display_alert_from_date
            }

            expect { put upcoming_reconciliations_path(namespace.id), headers: internal_api_headers, params: params }
              .not_to change { namespace.reload.upcoming_reconciliation }

            expect(namespace.upcoming_reconciliation.next_reconciliation_date).to eq(expected_next_reconciliation_date)
            expect(namespace.upcoming_reconciliation.display_alert_from).to eq(expected_display_alert_from_date)

            expect(response).to have_gitlab_http_status(:ok)
          end
        end
      end

      context 'when supplied with invalid params' do
        it 'returns an error' do
          params = {
            next_reconciliation_date: nil,
            display_alert_from: Date.today - 2.days
          }

          put upcoming_reconciliations_path(namespace.id), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:internal_server_error)
          expect(json_response['message']['error']).to include "Next reconciliation date can't be blank"
        end

        context 'when namespace does not exist' do
          it 'returns namespace not found error' do
            params = {
              next_reconciliation_date: Date.today + 5.days,
              display_alert_from: Date.today - 2.days
            }

            put upcoming_reconciliations_path(-1), headers: internal_api_headers, params: params

            expect(response).to have_gitlab_http_status(:not_found)
            expect(json_response['message']).to eq('404 Namespace Not Found')
          end
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with an admin personal access token' do
      let(:path) { "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/upcoming_reconciliations" }
      let(:namespace_id) { namespace.id }

      context 'when authenticated as user' do
        let_it_be(:user) { create(:user) }

        it 'returns authentication error' do
          put api(path, user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as admin' do
        let_it_be(:admin) { create(:admin) }

        let(:params) do
          {
            next_reconciliation_date: Date.today + 5.days,
            display_alert_from: Date.today - 2.days
          }
        end

        it_behaves_like 'PUT request permissions for admin mode' do
          let(:params) do
            {
              next_reconciliation_date: Date.today + 5.days,
              display_alert_from: Date.today - 2.days
            }
          end
        end

        subject(:put_upcoming_reconciliations) do
          put api(path, admin, admin_mode: true), params: params
        end

        it 'returns success' do
          put_upcoming_reconciliations

          expect(response).to have_gitlab_http_status(:ok)
        end

        context 'when update service failed' do
          let(:params) do
            {
              next_reconciliation_date: nil,
              display_alert_from: Date.today - 2.days
            }
          end

          it 'returns error' do
            put_upcoming_reconciliations

            expect(response).to have_gitlab_http_status(:internal_server_error)
            expect(json_response['message']['error']).to include "Next reconciliation date can't be blank"
          end
        end

        context 'when not gitlab.com' do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it 'returns 403 error' do
            put_upcoming_reconciliations

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(json_response['message']).to eq('403 Forbidden - This API is gitlab.com only!')
          end
        end
      end
    end
  end

  describe 'DELETE /internal/gitlab_subscriptions/namespaces/:namespace_id/upcoming_reconciliations' do
    let_it_be(:namespace) { create(:namespace) }

    context 'when unauthenticated' do
      it 'returns authentication error' do
        delete upcoming_reconciliations_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      subject(:delete_upcoming_reconciliation) do
        delete upcoming_reconciliations_path(namespace.id), headers: internal_api_headers
      end

      before do
        stub_internal_api_authentication
      end

      context 'when there is an upcoming reconciliation for the namespace' do
        it 'destroys the reconciliation and returns success' do
          create(:upcoming_reconciliation, namespace_id: namespace.id)

          expect { delete_upcoming_reconciliation }
            .to change { ::GitlabSubscriptions::UpcomingReconciliation.where(namespace_id: namespace.id).count }
            .by(-1)

          expect(response).to have_gitlab_http_status(:no_content)
        end
      end

      context 'when namespace does not exist' do
        it 'returns namespace not found error' do
          delete upcoming_reconciliations_path(-1), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response['message']).to eq('404 Namespace Not Found')
        end
      end

      context 'when the namespace_id does not have an upcoming reconciliation' do
        it 'returns a not found error' do
          expect { delete_upcoming_reconciliation }.not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with an admin personal access token' do
      let(:path) { "/internal/gitlab_subscriptions/namespaces/#{namespace.id}/upcoming_reconciliations" }

      it_behaves_like 'DELETE request permissions for admin mode' do
        before do
          create(:upcoming_reconciliation, namespace_id: namespace.id)
        end
      end

      context 'when authenticated as user' do
        it 'returns authentication error' do
          user = create(:user)

          expect { delete api(path, user) }
            .not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when authenticated as an admin' do
        let_it_be(:admin) { create(:admin) }

        context 'when the request is not for .com' do
          before do
            stub_saas_features(gitlab_com_subscriptions: false)
          end

          it 'returns an error' do
            expect { delete api(path, admin, admin_mode: true) }
              .not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

            expect(response).to have_gitlab_http_status(:forbidden)
            expect(response.body).to include('403 Forbidden - This API is gitlab.com only!')
          end
        end

        context 'when there is an upcoming reconciliation for the namespace' do
          it 'destroys the reconciliation and returns success' do
            create(:upcoming_reconciliation, namespace_id: namespace.id)

            expect { delete api(path, admin, admin_mode: true) }
              .to change { ::GitlabSubscriptions::UpcomingReconciliation.where(namespace_id: namespace.id).count }
              .by(-1)

            expect(response).to have_gitlab_http_status(:no_content)
          end
        end

        context 'when the namespace_id does not have an upcoming reconciliation' do
          it 'returns a not found error' do
            expect { delete api(path, admin, admin_mode: true) }
              .not_to change { GitlabSubscriptions::UpcomingReconciliation.count }

            expect(response).to have_gitlab_http_status(:not_found)
          end
        end
      end
    end
  end
end
