# frozen_string_literal: true

require 'spec_helper'

RSpec.describe UserDetail, feature_category: :system_access do
  it { is_expected.to belong_to(:provisioned_by_group) }
  it { is_expected.to belong_to(:enterprise_group).inverse_of(:enterprise_user_details) }

  describe 'validations' do
    context 'with support for hash with indifferent access - ind_jsonb' do
      specify do
        user_detail = build(:user_detail, onboarding_status: { 'step_url' => '_string_' })
        user_detail.onboarding_status[:email_opt_in] = true

        expect(user_detail).to be_valid
      end
    end
  end

  describe 'scopes' do
    describe '.with_enterprise_group' do
      subject(:scope) { described_class.with_enterprise_group }

      let_it_be(:user_detail_with_enterprise_group) { create(:enterprise_user).user_detail }
      let_it_be(:user_details_without_enterprise_group) { create_list(:user, 3, enterprise_group: nil) }

      it 'returns user details with enterprise group' do
        expect(scope).to contain_exactly(
          user_detail_with_enterprise_group
        )
      end
    end
  end

  context 'with loose foreign key on user_details.provisioned_by_group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:user, provisioned_by_group: parent).user_detail }
    end
  end

  context 'with loose foreign key on user_details.enterprise_group_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:group) }
      let_it_be(:model) { create(:user, enterprise_group: parent).user_detail }
    end
  end

  context 'with onboarding_status enum values' do
    let_it_be(:json_schema) do
      Gitlab::Json.parse(File.read(Rails.root.join('app/validators/json_schemas/user_detail_onboarding_status.json')))
    end

    it 'matches with role enum values in onboarding_status json schema' do
      role_enum = json_schema.dig('properties', 'role', 'enum')
      expect(role_enum).to eq(described_class.onboarding_status_roles.values)
    end

    it 'matches with registration_objective enum values in onboarding_status json schema' do
      registration_objective_enum = json_schema.dig('properties', 'registration_objective', 'enum')
      expect(registration_objective_enum).to eq(described_class.onboarding_status_registration_objectives.values)
    end
  end

  describe '#onboarding_status_registration_objective=' do
    let(:user_detail) { build(:user_detail) }

    context 'when given valid values' do
      it 'correctly handles string values' do
        value = 'basics'
        user_detail.onboarding_status_registration_objective = value
        expect(user_detail.onboarding_status_registration_objective).to eq(value)
      end

      it 'correctly handles integer values' do
        value = 0
        user_detail.onboarding_status_registration_objective = value
        expect(user_detail.onboarding_status_registration_objective).to eq('basics')
      end
    end

    context 'when given invalid values' do
      it 'returns nil for an invalid string value' do
        value = "something_invalid"
        user_detail.onboarding_status_registration_objective = value
        expect(user_detail.onboarding_status_registration_objective).to be_nil
      end

      it 'returns nil for an invalid integer value' do
        value = 100
        user_detail.onboarding_status_registration_objective = value
        expect(user_detail.onboarding_status_registration_objective).to be_nil
      end
    end
  end
end
