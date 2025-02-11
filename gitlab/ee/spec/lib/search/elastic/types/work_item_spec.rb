# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Elastic::Types::WorkItem, feature_category: :global_search do
  let(:helper) { Gitlab::Elastic::Helper.default }

  before do
    allow(Gitlab::Elastic::Helper).to receive(:default).and_return(helper)
  end

  describe '#target' do
    it 'returns work_item class' do
      expect(described_class.target.class.name).to eq(WorkItem.class.name)
    end
  end

  describe '#index_name' do
    it 'returns correct environment based index name' do
      expect(described_class.index_name).to eq('gitlab-test-work_items')
    end
  end

  describe '#mappings' do
    let(:mappings) { described_class.mappings.to_hash[:properties] }
    let(:expected_dimensions) { described_class::VERTEX_TEXT_EMBEDDING_DIMENSION }

    it 'always contains base mappings' do
      expect(mappings.keys).to include(:id)
    end

    it 'contains platform and version specific mappings' do
      if helper.vectors_supported?(:elasticsearch)
        expect(mappings.keys).to include(:embedding_0)
        expect(described_class.mappings.to_hash[:properties][:embedding_0][:dims]).to eq(expected_dimensions)
      end

      if helper.vectors_supported?(:opensearch)
        expect(mappings.keys).to include(:embedding_0)
        expect(described_class.mappings.to_hash[:properties][:embedding_0][:dimension]).to eq(expected_dimensions)
      end
    end
  end

  describe '#settings' do
    let(:settings) { described_class.settings.to_hash[:index].keys }

    it 'always contains base settings' do
      expect(settings).to include(:number_of_shards)
    end

    it 'contains platform and version specific mappings' do
      expect(settings).to include(:knn) if helper.vectors_supported?(:opensearch)
    end
  end
end
