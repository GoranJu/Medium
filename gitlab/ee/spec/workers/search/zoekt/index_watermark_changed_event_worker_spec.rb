# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexWatermarkChangedEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::IndexWatermarkChangedEvent.new(data: {}) }

  let_it_be(:healthy_index) { create(:zoekt_index, :healthy) }
  let_it_be(:watermark_level) { 'low_watermark_exceeded' }
  let_it_be(:max_storage_bytes) { 100 }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    context 'when no indexes have mismatched watermark levels or negative reserved storage bytes' do
      it 'does nothing' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).not_to receive(:log_extra_metadata_on_done)
        end
        expect(healthy_index).not_to receive(:update_reserved_storage_bytes!)

        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when indexes have mismatched watermark levels or negative reserved storage bytes' do
      let_it_be_with_reload(:negative_bytes_index) { create(:zoekt_index, :negative_reserved_storage_bytes) }
      let_it_be_with_reload(:mismatched_index) { create(:zoekt_index, :critical_watermark_exceeded) }

      before do
        mismatched_index.healthy!
      end

      it 'calls update_reserved_storage_bytes! on the indices' do
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { negative_bytes_index.reload.watermark_level }
          .from('healthy').to('overprovisioned')
          .and change { mismatched_index.reload.watermark_level }
          .from('healthy').to('critical_watermark_exceeded')
          .and not_change { healthy_index.reload.watermark_level }
      end

      context 'when update_reserved_storage_bytes! is raised on a record' do
        it 'does not raise an error' do
          allow(negative_bytes_index).to receive(:update_reserved_storage_bytes!)
            .and_raise ActiveRecord::RecordNotUnique

          expect { consume_event(subscriber: described_class, event: event) }.not_to raise_error
        end
      end

      it 'processes records in batches' do
        stub_const("#{described_class}::BATCH_SIZE", 1)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 1)
        end

        consume_event(subscriber: described_class, event: event)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 1)
        end

        consume_event(subscriber: described_class, event: event)
      end

      it 'logs metadata with number of indices updated' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 2)
        end

        consume_event(subscriber: described_class, event: event)
      end
    end
  end
end
