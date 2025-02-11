# frozen_string_literal: true

require "spec_helper"

RSpec.describe SamlGroupLinksHelper, feature_category: :system_access do
  describe '#saml_group_link_input_names' do
    subject(:saml_group_link_input_names) { helper.saml_group_link_input_names }

    it 'returns the correct data' do
      expected_data = {
        base_access_level_input_name: "saml_group_link[access_level]",
        member_role_id_input_name: "saml_group_link[member_role_id]"
      }

      expect(saml_group_link_input_names).to match(hash_including(expected_data))
    end
  end

  describe '#duo_seat_assignment_available?' do
    let_it_be(:group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects

    subject(:duo_seat_assignment_available?) { helper.duo_seat_assignment_available?(group) }

    it { is_expected.to be false }

    context 'when SaaS feature is available' do
      before do
        stub_saas_features(gitlab_duo_saas_only: true)
      end

      it { is_expected.to be false }

      context 'when there is an active add-on subscription' do
        let_it_be(:add_on_purchase) do
          create( # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects
            :gitlab_subscription_add_on_purchase,
            :gitlab_duo_pro,
            expires_on: 1.week.from_now.to_date,
            namespace: group
          )
        end

        it { is_expected.to be true }

        context 'when group is a subgroup' do
          let_it_be(:parent_group) { create(:group) } # rubocop:disable RSpec/FactoryBot/AvoidCreate -- Need persisted objects

          before_all do
            group.update!(parent: parent_group)
          end

          it { is_expected.to be false }
        end

        context 'when the subscription is not active' do
          before_all do
            add_on_purchase.update!(expires_on: 1.week.ago.to_date)
          end

          it { is_expected.to be false }
        end

        context 'when the feature flag is disabled' do
          before do
            stub_feature_flags(saml_groups_duo_add_on_assignment: false)
          end

          it { is_expected.to be false }
        end
      end
    end
  end
end
