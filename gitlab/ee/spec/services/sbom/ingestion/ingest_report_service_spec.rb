# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::Ingestion::IngestReportService, feature_category: :dependency_management do
  let_it_be(:num_components) { 283 }
  let_it_be(:pipeline) { build_stubbed(:ci_pipeline) }
  let_it_be(:sbom_report) { create(:ci_reports_sbom_report, num_components: num_components) }

  let(:sequencer) { ::Ingestion::Sequencer.new }
  let(:source_sequencer) { ::Ingestion::Sequencer.new(start: num_components + 1) }

  subject(:execute) { described_class.execute(pipeline, sbom_report) }

  describe '#execute' do
    before do
      allow(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .and_wrap_original do |_, _, occurrence_maps|
        {
          occurrence_ids: occurrence_maps.map { sequencer.next },
          source_ids: occurrence_maps.map { source_sequencer.next }
        }
      end
    end

    it 'executes IngestReportSliceService in batches' do
      full_batches, remainder = num_components.divmod(described_class::BATCH_SIZE)

      expect(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .with(pipeline, an_object_having_attributes(size: described_class::BATCH_SIZE)).exactly(full_batches).times
      expect(::Sbom::Ingestion::IngestReportSliceService).to receive(:execute)
        .with(pipeline, an_object_having_attributes(size: remainder)).once

      result = execute
      all_occurrence_ids = result.flat_map { |batch| batch[:occurrence_ids] }
      all_source_ids = result.flat_map { |batch| batch[:source_ids] }

      expect(all_occurrence_ids).to match_array(sequencer.range)
      expect(all_source_ids).to match_array(source_sequencer.range)
    end
  end
end
