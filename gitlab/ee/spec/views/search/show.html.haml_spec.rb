# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'search/show', feature_category: :global_search do
  let(:search_term) { nil }
  let(:user) { build(:user) }
  let(:search_service_presenter) do
    instance_double(SearchServicePresenter,
      without_count?: false,
      advanced_search_enabled?: false,
      zoekt_enabled?: false
    )
  end

  before do
    allow(view).to receive(:current_user) { user }

    assign(:search_service_presenter, search_service_presenter)
  end

  describe 'SSO session expired' do
    let_it_be(:groups_requiring_reauth) { create_list(:group, 2) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- persisted record required
    let(:search_results) do
      instance_double(Gitlab::SearchResults).tap do |double|
        allow(double).to receive(:formatted_count).and_return(0)
      end
    end

    before do
      assign(:search_results, search_results)

      allow(view).to receive_messages(search_navigation_json: {},
        params: {},
        user_groups_requiring_reauth: groups_requiring_reauth,
        search_service: search_service
      )
    end

    context 'when search type is global' do
      let(:search_service) do
        instance_double(SearchService,
          level: 'global',
          search_type: 'basic'
        )
      end

      it 'renders the saml reauth notice partial when groups require reauth' do
        render

        expect(view).to have_rendered(partial: 'shared/dashboard/saml_reauth_notice',
          locals: { groups_requiring_saml_reauth: groups_requiring_reauth })
      end

      context 'when search_global_sso_redirect is false' do
        before do
          stub_feature_flags(search_global_sso_redirect: false)
        end

        it 'does not render the saml reauth notice when no groups require reauth' do
          render

          expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
        end
      end

      it 'does not render the saml reauth notice when no groups require reauth' do
        allow(view).to receive(:user_groups_requiring_reauth).and_return([])

        render

        expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
      end
    end

    context 'when search level is group' do
      let(:search_service) do
        instance_double(SearchService,
          level: 'group',
          search_type: 'basic'
        )
      end

      it 'does not render the saml reauth notice partial when groups require reauth' do
        render

        expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
      end
    end

    context 'when search level is project' do
      let(:search_service) do
        instance_double(SearchService,
          level: 'project',
          search_type: 'basic'
        )
      end

      it 'does not render the saml reauth notice partial when groups require reauth' do
        render

        expect(view).not_to have_rendered(partial: 'shared/dashboard/saml_reauth_notice')
      end
    end
  end
end
