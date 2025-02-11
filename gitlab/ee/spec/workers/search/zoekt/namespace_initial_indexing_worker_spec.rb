# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NamespaceInitialIndexingWorker, feature_category: :global_search do
  it_behaves_like 'worker with data consistency', described_class, data_consistency: :always

  describe '#perform' do
    let_it_be(:zoekt_index) { create(:zoekt_index) }
    let_it_be(:job_args) { [zoekt_index.id] }

    subject(:perform_worker) { described_class.new.perform(*job_args) }

    it_behaves_like 'an idempotent worker' do
      it 'performs a no-op' do
        expect(::Search::Zoekt).not_to receive(:licensed_and_indexing_enabled?)
        expect(::Search::Zoekt).not_to receive(:index_in)
        expect(::Search::Zoekt::Index).not_to receive(:find_by_id)
        expect(described_class).not_to receive(:perform_in)

        perform_worker
      end
    end
  end
end
