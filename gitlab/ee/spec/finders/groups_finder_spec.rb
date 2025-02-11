# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupsFinder, feature_category: :groups_and_projects do
  include AdminModeHelper

  describe '#execute' do
    let_it_be(:user) { create(:user) }
    let_it_be(:group_with_wiki) { create(:group, :wiki_repo) }
    let_it_be(:group_without_wiki) { create(:group) }

    subject { described_class.new(user, params).execute }

    before_all do
      group_with_wiki.add_developer(user)
      group_without_wiki.add_developer(user)
    end

    context 'when repository storage name is given' do
      let(:params) { { repository_storage: group_with_wiki.repository_storage } }

      it 'filters by the repository storage name' do
        expect(subject).to eq([group_with_wiki])
      end
    end

    context 'when repository storage name is not given' do
      let(:params) { {} }

      it 'returns all groups' do
        expect(subject).to match_array([group_with_wiki, group_without_wiki])
      end
    end
  end

  describe '#by_saml_sso_session' do
    let_it_be(:current_user) { create(:user) }
    let_it_be(:root_group1) { create(:group, saml_provider: create(:saml_provider), developers: current_user) }
    let_it_be(:root_group2) { create(:group, saml_provider: create(:saml_provider), developers: current_user) }
    let_it_be(:private_root_group) do
      create(:group, :private, saml_provider: create(:saml_provider), developers: current_user)
    end

    let_it_be(:subgroup1) { create(:group, parent: root_group1) }
    let_it_be(:subgroup2) { create(:group, parent: root_group2) }
    let_it_be(:private_subgroup) { create(:group, :private, parent: private_root_group) }
    let_it_be(:all_groups) { [root_group1, subgroup1, root_group2, subgroup2, private_root_group, private_subgroup] }

    let(:params) { { filter_expired_saml_session_groups: true } }
    let(:finder) { described_class.new(current_user, params) }

    subject(:groups) { finder.execute.id_in(all_groups).to_a }

    before_all do
      [root_group1, private_root_group].each do |root_group|
        create(:group_saml_identity, saml_provider: root_group.saml_provider, user: current_user)
      end
    end

    context 'when the current user is nil' do
      let_it_be(:current_user) { nil }

      it 'includes public SAML groups' do
        expect(groups).to contain_exactly(root_group1, subgroup1, root_group2, subgroup2)
      end
    end

    shared_examples 'includes all SAML groups' do
      specify do
        expect(groups).to match_array(all_groups)
      end
    end

    context 'when the current user is an admin', :enable_admin_mode do
      let_it_be(:current_user) { create(:admin) }

      it_behaves_like 'includes all SAML groups'
    end

    context 'when the current user has no active SAML sessions' do
      it 'filters out the SAML member groups' do
        expect(groups).to contain_exactly(root_group2, subgroup2)
      end
    end

    context 'when filter_expired_saml_session_groups param is false' do
      let(:params) { { filter_expired_saml_session_groups: false } }

      it_behaves_like 'includes all SAML groups'
    end

    context 'when the current user has active SAML sessions' do
      before do
        active_saml_sessions = { root_group1.saml_provider.id => Time.current,
                                 private_root_group.saml_provider.id => Time.current }
        allow(::Gitlab::Auth::GroupSaml::SsoState).to receive(:active_saml_sessions).and_return(active_saml_sessions)
      end

      it_behaves_like 'includes all SAML groups'
    end
  end
end
