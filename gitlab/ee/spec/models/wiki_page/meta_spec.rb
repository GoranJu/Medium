# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WikiPage::Meta, feature_category: :wiki do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:other_group) { create(:group, :private) }

  before do
    stub_licensed_features(group_wikis: true)
  end

  include_examples 'creating wiki page meta record examples' do
    let(:container) { group }
    let(:other_container) { other_group }
  end

  describe '#resource_parent' do
    subject(:meta) { described_class.new(title: 'some title', namespace: group) }

    it 'returns container' do
      expect(meta.resource_parent).to eq(group)
    end
  end
end
