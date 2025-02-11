# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Admin::GitlabDuo::ConfigurationController, :cloud_licenses, feature_category: :ai_abstraction_layer do
  include AdminModeHelper

  subject(:get_index) { get admin_gitlab_duo_configuration_index_path }

  describe 'GET /code_suggestions', :with_cloud_connector do
    let(:plan) { License::STARTER_PLAN }
    let(:license) { build(:license, plan: plan) }

    before do
      allow(License).to receive(:current).and_return(license)
      allow(::Gitlab::Saas).to receive(:feature_available?).and_return(false)
    end

    shared_examples 'redirects configuration path' do
      it 'redirects to admin_gitlab_duo_path' do
        get_index

        expect(response).to have_gitlab_http_status(:redirect)
        expect(response).to redirect_to(admin_gitlab_duo_path)
      end
    end

    shared_examples 'renders duo settings form' do
      context 'when duo pro addon is purchased' do
        let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro, :active) }

        it 'renders duo settings form' do
          get_index

          expect(response).to render_template(:index)
          expect(response.body).to include('js-ai-settings')
        end
      end
    end

    context 'when the user is not admin' do
      let_it_be(:user) { create(:user) }

      before do
        sign_in(user)
      end

      it 'returns 404' do
        get_index

        expect(response).to have_gitlab_http_status(:not_found)
        expect(response).to render_template('errors/not_found')
      end
    end

    context 'when the user is an admin' do
      let_it_be(:admin) { create(:admin) }

      before do
        login_as(admin)
        enable_admin_mode!(admin)
      end

      context 'when instance is self-managed' do
        before do
          allow(Gitlab).to receive(:com?).and_return(false)
        end

        context 'with a paid license' do
          it_behaves_like 'renders duo settings form'
        end
      end

      context 'when instance is SaaS' do
        before do
          allow(Gitlab).to receive(:com?).and_return(true)
        end

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance does not have duo chat availabile' do
        before do
          allow(controller).to receive_messages(admin_display_ai_powered_chat_settings?: true,
            admin_display_duo_addon_settings?: false)
        end

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance does not have duo pro availabile' do
        before do
          allow(controller).to receive_messages(admin_display_ai_powered_chat_settings?: false,
            admin_display_duo_addon_settings?: true)
        end

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance has a non-paid license' do
        let(:plan) { License::LEGACY_LICENSE_TYPE }

        it_behaves_like 'redirects configuration path'
      end

      context 'when the instance does not have a license' do
        let(:license) { nil }

        it_behaves_like 'redirects configuration path'
      end
    end
  end
end
