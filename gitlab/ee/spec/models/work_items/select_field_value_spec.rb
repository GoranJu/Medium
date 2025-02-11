# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::SelectFieldValue, feature_category: :team_planning do
  subject(:select_field_value) { build(:work_item_select_field_value) }

  it_behaves_like 'a work item custom field value', factory: :work_item_select_field_value

  describe 'associations' do
    it { is_expected.to belong_to(:custom_field_select_option) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:custom_field_select_option) }

    it 'validates uniqueness of custom_field_select_option' do
      # Prevent errors when validate_uniqueness_of creates duplicate records without going through our model hooks
      select_field_value.namespace_id = create(:group).id

      is_expected.to validate_uniqueness_of(:custom_field_select_option).scoped_to([:work_item_id, :custom_field_id])
    end
  end
end
