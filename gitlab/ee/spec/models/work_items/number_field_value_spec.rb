# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::NumberFieldValue, feature_category: :team_planning do
  subject(:number_field_value) { build(:work_item_number_field_value) }

  it_behaves_like 'a work item custom field value', factory: :work_item_number_field_value

  describe 'validations' do
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_numericality_of(:value) }
  end
end
