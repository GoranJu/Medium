# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ProjectLinksHelper, feature_category: :system_access do
  let_it_be(:project) { build(:project) }

  describe '#custom_role_for_project_link_enabled?' do
    subject(:enabled) { helper.custom_role_for_project_link_enabled?(project) }

    before do
      stub_licensed_features(custom_roles: true)
    end

    context 'when on SaaS', :saas do
      it { is_expected.to be(true) }

      context 'when feature flag `assign_custom_roles_to_project_links_saas` is disabled' do
        before do
          stub_feature_flags(assign_custom_roles_to_project_links_saas: false)
        end

        it { is_expected.to be(false) }
      end

      context 'when custom roles is disabled' do
        before do
          stub_licensed_features(custom_roles: false)
        end

        it { is_expected.to be(false) }
      end
    end

    it { is_expected.to be(false) }
  end
end
