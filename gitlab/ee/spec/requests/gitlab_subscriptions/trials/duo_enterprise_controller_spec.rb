# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::DuoEnterpriseController, :saas, :unlimited_max_formatted_output_length, feature_category: :plan_provisioning do
  let_it_be(:user) { create(:user) }
  let_it_be(:user_without_eligible_groups) { create(:user) }
  let_it_be(:group) { create(:group_with_plan, plan: :ultimate_plan, owners: user) }
  let_it_be(:another_free_group) { create(:group, owners: user) }
  let_it_be(:another_ultimate_group) { create(:group_with_plan, plan: :ultimate_plan, developers: user) }
  let_it_be(:ineligible_paid_group) { create(:group_with_plan, plan: :premium_plan, owners: user) }
  let_it_be(:add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

  let(:subscriptions_trials_saas_feature) { true }

  before do
    stub_saas_features(
      subscriptions_trials: subscriptions_trials_saas_feature,
      marketing_google_tag_manager: false
    )
  end

  shared_examples 'namespace is not eligible for trial' do
    context 'when free group owner' do
      let(:namespace_id) { { namespace_id: another_free_group.id } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'for an ineligible group owner' do
      let(:namespace_id) { { namespace_id: ineligible_paid_group.id } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end

    context 'when eligible paid plan group developer' do
      let(:namespace_id) { { namespace_id: another_ultimate_group.id } }

      it { is_expected.to have_gitlab_http_status(:forbidden) }
    end
  end

  shared_examples 'no eligible namespaces' do
    before do
      login_as(user_without_eligible_groups)
    end

    it { is_expected.to have_gitlab_http_status(:forbidden) }
  end

  shared_examples 'group_name assignment' do
    context 'when there is only one eligible namespace' do
      it 'assigns the group_name to the eligible group name' do
        request

        expect(assigns(:group_name)).to eq(group_for_trial.name)
      end
    end

    context 'when there are multiple eligible namespaces' do
      before_all do
        create(:group_with_plan, plan: :ultimate_plan, owners: user)
      end

      context 'when namespace_id is provided' do
        it 'assigns the group_name provided from params' do
          request

          expect(assigns(:group_name)).to eq(group_for_trial.name)
        end
      end

      context 'when namespace_id is not provided' do
        let(:namespace_id) { {} }

        it 'assigns the group_name to nil' do
          request

          expect(assigns(:group_name)).to be_nil
        end
      end
    end
  end

  describe 'GET new' do
    let(:group_for_trial) { group }
    let(:namespace_id) { { namespace_id: group_for_trial.id } }
    let(:base_params) { namespace_id }

    subject(:get_new) do
      get new_trials_duo_enterprise_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it { is_expected.to redirect_to_sign_in }
    end

    context 'when authenticated as a user' do
      before do
        login_as(user)
      end

      it { is_expected.to render_lead_form_duo_enterprise }

      it_behaves_like 'group_name assignment' do
        let(:request) { get_new }
      end

      context 'with tracking page render' do
        it_behaves_like 'internal event tracking' do
          let(:event) { 'render_duo_enterprise_lead_page' }
          let(:namespace) { group }

          subject(:track_event) do
            get new_trials_duo_enterprise_path, params: { namespace_id: group.id }
          end
        end
      end

      context 'when subscriptions_trials saas feature is not available' do
        let(:subscriptions_trials_saas_feature) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it_behaves_like 'namespace is not eligible for trial'
    end

    it_behaves_like 'no eligible namespaces'
  end

  describe 'POST create' do
    let(:group_for_trial) { group }
    let(:step) { GitlabSubscriptions::Trials::CreateDuoEnterpriseService::LEAD }
    let(:namespace_id) { { namespace_id: group_for_trial.id.to_s } }
    let(:lead_params) do
      {
        company_name: '_company_name_',
        company_size: '1-99',
        first_name: '_first_name_',
        last_name: '_last_name_',
        phone_number: '123',
        country: '_country_',
        state: '_state_',
        website_url: '_website_url_'
      }.with_indifferent_access
    end

    let(:trial_params) do
      namespace_id.with_indifferent_access
    end

    let(:base_params) { lead_params.merge(trial_params).merge(step: step) }

    subject(:post_create) do
      post trials_duo_enterprise_path, params: base_params
      response
    end

    context 'when not authenticated' do
      it 'redirects to trial registration' do
        expect(post_create).to redirect_to_sign_in
      end
    end

    context 'when authenticated as a user' do
      before do
        login_as(user)
      end

      context 'when successful' do
        context 'when add_on_purchase exists' do
          let(:add_on_purchase) do
            build(:gitlab_subscription_add_on_purchase, expires_on: 61.days.from_now)
          end

          before do
            expect_create_success
          end

          it { is_expected.to redirect_to(group_settings_gitlab_duo_path(group_for_trial)) }

          it 'shows valid flash message', :freeze_time do
            post_create

            message = s_(
              'DuoEnterpriseTrial|You have successfully started a Duo Enterprise trial that will expire on %{exp_date}.'
            )
            formatted_message = format(
              message,
              exp_date: I18n.l(61.days.from_now.to_date, format: :long)
            )
            expect(flash[:success]).to have_content(formatted_message)
          end
        end

        def expect_create_success
          service_params = {
            step: step,
            lead_params: lead_params,
            trial_params: trial_params,
            user: user
          }

          expect_next_instance_of(GitlabSubscriptions::Trials::CreateDuoEnterpriseService, service_params) do |instance|
            expect(instance).to receive(:execute).and_return(
              ServiceResponse.success(payload: { namespace: group_for_trial, add_on_purchase: add_on_purchase })
            )
          end
        end
      end

      context 'with create service failures' do
        let(:payload) { {} }

        before do
          expect_create_failure(failure_reason, payload)
        end

        context 'when namespace is not found or not allowed to create' do
          let(:failure_reason) { :not_found }

          it { is_expected.to have_gitlab_http_status(:not_found) }
        end

        context 'when lead creation fails' do
          let(:failure_reason) { :lead_failed }

          it { is_expected.to have_gitlab_http_status(:ok).and render_lead_form_duo_enterprise }

          it_behaves_like 'group_name assignment' do
            let(:request) { post_create }
          end
        end

        context 'when lead creation is successful, but we need to select a namespace next to apply trial' do
          let(:failure_reason) { :no_single_namespace }
          let(:payload) do
            {
              trial_selection_params: {
                step: GitlabSubscriptions::Trials::CreateDuoProService::TRIAL
              }
            }
          end

          it { is_expected.to redirect_to(new_trials_duo_enterprise_path(payload[:trial_selection_params])) }
        end

        context 'with trial failure' do
          let(:failure_reason) { :trial_failed }

          it 'renders the select namespace form again with trial creation errors only' do
            expect(post_create).to render_select_namespace_duo_enterprise

            expect(response.body).to include(_('your GitLab Duo Enterprise trial could not be created'))
          end
        end

        context 'with random failure' do
          let(:failure_reason) { :random_error }

          it { is_expected.to render_select_namespace_duo_enterprise }
        end

        def expect_create_failure(reason, payload = {})
          expect_next_instance_of(GitlabSubscriptions::Trials::CreateDuoEnterpriseService) do |instance|
            response = ServiceResponse.error(message: '_error_', reason: reason, payload: payload)
            expect(instance).to receive(:execute).and_return(response)
          end
        end
      end

      context 'when subscriptions_trials saas feature is not available' do
        let(:subscriptions_trials_saas_feature) { false }

        it { is_expected.to have_gitlab_http_status(:not_found) }
      end

      it_behaves_like 'namespace is not eligible for trial'
    end

    it_behaves_like 'no eligible namespaces'
  end
end
