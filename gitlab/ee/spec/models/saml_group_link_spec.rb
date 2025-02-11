# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SamlGroupLink do
  describe 'associations' do
    it { is_expected.to belong_to(:group) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:group) }
    it { is_expected.to validate_presence_of(:access_level) }
    it { is_expected.to validate_presence_of(:saml_group_name) }
    it { is_expected.to validate_length_of(:saml_group_name).is_at_most(255) }

    context 'group name uniqueness' do
      before do
        create(:saml_group_link, group: create(:group))
      end

      it { is_expected.to validate_uniqueness_of(:saml_group_name).scoped_to([:group_id]) }
    end

    context 'saml_group_name with whitespaces' do
      it 'saves group link name without whitespace' do
        saml_group_link = described_class.new(saml_group_name: '   group   ')
        saml_group_link.valid?

        expect(saml_group_link.saml_group_name).to eq('group')
      end
    end

    context 'minimal access role' do
      let_it_be(:top_level_group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: top_level_group) }

      def saml_group_link(group:)
        build(:saml_group_link, group: group, access_level: ::Gitlab::Access::MINIMAL_ACCESS)
      end

      before do
        stub_licensed_features(minimal_access_role: true)
      end

      it 'allows the role at the top level group' do
        expect(saml_group_link(group: top_level_group)).to be_valid
      end

      it 'does not allow the role for subgroups' do
        expect(saml_group_link(group: subgroup)).not_to be_valid
      end
    end
  end

  describe 'scopes' do
    let_it_be(:group) { create(:group) }
    let_it_be(:group_link) { create(:saml_group_link, group: group) }

    describe '.by_id_and_group_id' do
      it 'finds the group link' do
        results = described_class.by_id_and_group_id(group_link.id, group.id)

        expect(results).to match_array([group_link])
      end

      context 'with multiple groups and group links' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:group_link2) { create(:saml_group_link, group: group2) }

        it 'finds group links within the given groups' do
          results = described_class.by_id_and_group_id([group_link, group_link2], [group, group2])

          expect(results).to match_array([group_link, group_link2])
        end

        it 'does not find group links outside the given groups' do
          results = described_class.by_id_and_group_id([group_link, group_link2], [group])

          expect(results).to match_array([group_link])
        end
      end
    end

    describe '.by_saml_group_name' do
      it 'finds the group link' do
        results = described_class.by_saml_group_name(group_link.saml_group_name)

        expect(results).to match_array([group_link])
      end

      context 'with multiple groups and group links' do
        let_it_be(:group2) { create(:group) }
        let_it_be(:group_link2) { create(:saml_group_link, group: group2) }

        it 'finds group links within the given groups' do
          results = described_class.by_saml_group_name([group_link.saml_group_name, group_link2.saml_group_name])

          expect(results).to match_array([group_link, group_link2])
        end
      end
    end

    describe '.by_assign_duo_seats' do
      let_it_be(:group_link_w_assign_duo_seats) { create(:saml_group_link, assign_duo_seats: true) }

      it 'finds group links with correct value' do
        results = described_class.by_assign_duo_seats(true)

        expect(results).to contain_exactly(group_link_w_assign_duo_seats)
      end
    end
  end

  it_behaves_like 'model with member role relation' do
    subject(:model) { build(:saml_group_link) }

    context 'when the member role namespace is in the same hierarchy', feature_category: :permissions do
      before do
        model.member_role = create(:member_role, namespace: model.group, base_access_level: Gitlab::Access::GUEST)
        model.group = create(:group, parent: model.group)
      end

      it { is_expected.to be_valid }
    end
  end
end
