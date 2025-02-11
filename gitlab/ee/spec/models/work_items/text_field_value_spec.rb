# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::TextFieldValue, feature_category: :team_planning do
  subject(:text_field_value) { build(:work_item_text_field_value) }

  it_behaves_like 'a work item custom field value', factory: :work_item_text_field_value

  describe 'validations' do
    it { is_expected.to validate_presence_of(:value) }
    it { is_expected.to validate_length_of(:value).is_at_most(described_class::MAX_LENGTH) }
  end
end
