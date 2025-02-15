# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::AddOnPurchases, :aggregate_failures, :api, feature_category: :"add-on_provisioning" do
  include GitlabSubscriptions::InternalApiHelpers

  let_it_be(:namespace) { create(:group, :with_organization) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
  let(:namespace_id) { namespace.id }
  let(:add_on_name) { add_on.name }
  let(:add_on_purchases_path) do
    internal_api("namespaces/#{namespace_id}/subscription_add_on_purchases/#{add_on_name}")
  end

  describe 'POST /internal/gitlab_subscriptions/namespaces/:id/subscription_add_on_purchases' do
    let(:add_on_purchases_path) do
      internal_api("namespaces/#{namespace_id}/subscription_add_on_purchases")
    end

    let(:started_on) { Date.current.to_s }
    let(:expires_on) { 1.year.from_now.to_date.to_s }
    let(:namespace_id) { namespace.id }
    let(:purchase_xid) { "A-12345" }
    let(:quantity) { 10 }
    let(:trial) { true }

    let(:params) do
      {
        add_on_purchases: {
          duo_pro: [
            add_on_product
          ]
        }
      }
    end

    let(:add_on_product) do
      {
        started_on: started_on,
        expires_on: expires_on,
        purchase_xid: purchase_xid,
        quantity: quantity,
        trial: trial
      }
    end

    shared_examples 'bulk add-on purchase provision service endpoint' do
      context 'when the namespace cannot be found' do
        let(:namespace_id) { non_existing_record_id }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it 'creates a new add-on purchase', :freeze_time do
        expect { result }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(result).to have_gitlab_http_status(:success)
        expect(json_response.first).to eq(
          'namespace_id' => namespace_id,
          'namespace_name' => namespace.name,
          'add_on' => add_on.name.titleize,
          'started_on' => add_on_product[:started_on],
          'expires_on' => add_on_product[:expires_on],
          'purchase_xid' => add_on_product[:purchase_xid],
          'quantity' => add_on_product[:quantity],
          'trial' => add_on_product[:trial]
        )
      end

      context 'when body is missing parameters' do
        let(:add_on_product) do
          {
            started_on: started_on,
            expires_on: expires_on,
            quantity: 1
          }
        end

        it 'returns bad request response highlighting validation errors' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:bad_request)
          expect(result.body).to include('"purchase_xid":["can\'t be blank"]')
        end
      end

      context 'when a negative integer for quantity is provided' do
        let(:quantity) { -1 }

        it 'returns active record errors' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:bad_request)
          expect(result.body).to include('Must be a non-negative integer if provided')
        end
      end

      context 'when the add-on purchase already exists' do
        let(:existing_add_on_purchase_params) do
          {
            quantity: 5,
            purchase_xid: 'trial-order-12345',
            trial: true
          }
        end

        let(:trial) { false }

        before do
          create(
            :gitlab_subscription_add_on_purchase,
            namespace: namespace,
            add_on: add_on,
            quantity: existing_add_on_purchase_params[:quantity],
            purchase_xid: existing_add_on_purchase_params[:purchase_xid],
            trial: existing_add_on_purchase_params[:trial]
          )
        end

        it 'updates existing add-on purchase' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:success)
          expect(json_response.first).to eq(
            'namespace_id' => namespace_id,
            'namespace_name' => namespace.name,
            'add_on' => add_on.name.titleize,
            'started_on' => add_on_product[:started_on],
            'expires_on' => add_on_product[:expires_on],
            'purchase_xid' => add_on_product[:purchase_xid],
            'quantity' => add_on_product[:quantity],
            'trial' => add_on_product[:trial]
          )
        end

        context 'when only required add-on purchase params are used' do
          let(:add_on_product) do
            {
              started_on: started_on,
              expires_on: expires_on
            }
          end

          it 'updates existing add-on purchase' do
            expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

            expect(result).to have_gitlab_http_status(:success)
            expect(json_response.first).to eq(
              'namespace_id' => namespace_id,
              'namespace_name' => namespace.name,
              'add_on' => add_on.name.titleize,
              'started_on' => add_on_product[:started_on],
              'expires_on' => add_on_product[:expires_on],
              'purchase_xid' => existing_add_on_purchase_params[:purchase_xid],
              'quantity' => existing_add_on_purchase_params[:quantity],
              'trial' => existing_add_on_purchase_params[:trial]
            )
          end
        end
      end

      context 'when parameters miss information' do
        let_it_be(:error) { ServiceResponse.error(message: 'Something went wrong') }

        before do
          allow_next_instance_of(GitlabSubscriptions::AddOnPurchases::CreateService) do |instance|
            allow(instance).to receive(:execute).and_return error
          end
        end

        it 'returns bad request response' do
          expect { result }.not_to change { GitlabSubscriptions::AddOnPurchase.count }

          expect(result).to have_gitlab_http_status(:bad_request)
          expect(result.body).to include('Something went wrong')
        end
      end
    end

    subject do
      post add_on_purchases_path
      response
    end

    it { is_expected.to have_gitlab_http_status(:unauthorized) }

    context 'when authenticated as the subscription portal' do
      subject(:result) do
        post add_on_purchases_path, headers: internal_api_headers, params: params
        response
      end

      before do
        stub_internal_api_authentication
      end

      it_behaves_like 'bulk add-on purchase provision service endpoint'
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      subject(:result) do
        post api(add_on_purchases_path, user, admin_mode: true), params: params
        response
      end

      let(:user) { create(:admin) }
      let(:admin_mode) { true }
      let(:add_on_purchases_path) do
        "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/subscription_add_on_purchases"
      end

      it_behaves_like 'bulk add-on purchase provision service endpoint'

      context 'with a non-admin user' do
        let(:user) { create(:user) }
        let(:admin_mode) { false }

        it { is_expected.to have_gitlab_http_status(:forbidden) }
      end
    end
  end

  describe 'GET /namespaces/:id/subscription_add_on_purchases/:add_on_name' do
    context 'when unauthenticated' do
      it 'returns authentication error' do
        get add_on_purchases_path

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        let(:namespace_id) { non_existing_record_id }

        it 'returns a not_found error' do
          get add_on_purchases_path, headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on cannot be found' do
        let(:add_on_name) { 'non-existing-add-on' }

        it 'returns a not_found error' do
          get add_on_purchases_path, headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on purchase does not exist' do
        it 'returns a not_found error' do
          get add_on_purchases_path, headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the add-on purchase exists' do
        it 'returns the found add-on purchase' do
          add_on_purchase = create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on)

          get add_on_purchases_path, headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:success)
          expect(json_response).to eq(
            'namespace_id' => namespace.id,
            'namespace_name' => namespace.name,
            'add_on' => add_on.name.titleize,
            'quantity' => add_on_purchase.quantity,
            'started_on' => add_on_purchase.started_at.to_s,
            'expires_on' => add_on_purchase.expires_on.to_s,
            'purchase_xid' => add_on_purchase.purchase_xid,
            'trial' => add_on_purchase.trial
          )
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with a personal access token' do
      let_it_be(:admin) { create(:admin) }
      let_it_be(:purchase_xid) { 'S-A00000001' }

      let(:add_on_purchases_path) do
        "/internal/gitlab_subscriptions/namespaces/#{namespace_id}/subscription_add_on_purchases/#{add_on_name}"
      end

      subject(:get_add_on_purchase) do
        get api(add_on_purchases_path, user, admin_mode: admin_mode)

        response
      end

      context 'with a non-admin user' do
        let_it_be(:admin_mode) { false }
        let_it_be(:user) { create(:user) }

        it 'returns :forbidden' do
          get_add_on_purchase

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'with admin user' do
        let_it_be(:admin_mode) { true }
        let_it_be(:user) { admin }

        context 'when the namespace cannot be found' do
          let(:namespace_id) { non_existing_record_id }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on cannot be found' do
          let(:add_on_name) { 'non-existing-add-on' }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on purchase does not exist' do
          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when the add-on purchase exists' do
          it 'returns the found add-on purchase' do
            add_on_purchase = create(
              :gitlab_subscription_add_on_purchase,
              namespace: namespace,
              add_on: add_on,
              quantity: 5,
              purchase_xid: purchase_xid
            )

            get_add_on_purchase

            expect(response).to have_gitlab_http_status(:success)
            expect(json_response).to eq(
              'namespace_id' => namespace_id,
              'namespace_name' => namespace.name,
              'add_on' => add_on.name.titleize,
              'quantity' => add_on_purchase.quantity,
              'started_on' => add_on_purchase.started_at.to_s,
              'expires_on' => add_on_purchase.expires_on.to_s,
              'purchase_xid' => add_on_purchase.purchase_xid,
              'trial' => add_on_purchase.trial
            )
          end
        end
      end
    end
  end
end
