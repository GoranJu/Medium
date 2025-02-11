# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Issuables::CustomFieldSelectOption, feature_category: :team_planning do
  subject(:custom_field_select_option) { build(:custom_field_select_option) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:custom_field) }
  end

  describe 'validations' do
    it 'validates presence of namespace' do
      # prevents copy_namespace_from_custom_field from interfering with the test
      custom_field_select_option.custom_field = nil

      is_expected.to validate_presence_of(:namespace)
    end

    it { is_expected.to validate_presence_of(:custom_field) }
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(255) }
    it { is_expected.to validate_uniqueness_of(:value).scoped_to(:custom_field_id).case_insensitive }
  end

  describe '#copy_namespace_from_custom_field' do
    let(:custom_field) { build(:custom_field) }

    it 'copies namespace_id from the associated custom field' do
      expect(custom_field_select_option.namespace_id).to be_nil

      custom_field_select_option.custom_field = custom_field
      custom_field_select_option.valid?

      expect(custom_field_select_option.namespace_id).to eq(custom_field.namespace_id)
    end
  end
end
