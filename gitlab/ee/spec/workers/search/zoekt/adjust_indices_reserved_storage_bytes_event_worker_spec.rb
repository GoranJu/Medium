# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::AdjustIndicesReservedStorageBytesEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::AdjustIndicesReservedStorageBytesEvent.new(data: {}) }
  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:healthy_index) { create(:zoekt_index, :healthy) }

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'subscribes to event'

  it_behaves_like 'an idempotent worker' do
    context 'when the should_be_reserved_storage_bytes_adjusted scope returns no data' do
      it 'does nothing' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).not_to receive(:log_extra_metadata_on_done)
        end
        expect(healthy_index).not_to receive(:update_reserved_storage_bytes!)

        consume_event(subscriber: described_class, event: event)
      end
    end

    context 'when the should_be_reserved_storage_bytes_adjusted scope returns data' do
      let_it_be_with_reload(:overprovisioned_pending_index) { create(:zoekt_index, :overprovisioned) }
      let_it_be_with_reload(:overprovisioned_ready_index) { create(:zoekt_index, :overprovisioned, :ready) }
      let_it_be_with_reload(:high_watermark_exceeded_pending_index) do
        create(:zoekt_index, :high_watermark_exceeded, node: node)
      end

      let_it_be_with_reload(:high_watermark_exceeded_ready_index) do
        create(:zoekt_index, :high_watermark_exceeded, :ready, node: node)
      end

      it 'calls update_reserved_storage_bytes! on the Search::Zoekt::Index.should_be_reserved_storage_bytes_adjusted' do
        expect { consume_event(subscriber: described_class, event: event) }
          .to change { overprovisioned_ready_index.reload.watermark_level }
            .from('overprovisioned').to('healthy')
          .and change { high_watermark_exceeded_pending_index.reload.watermark_level }
            .from('high_watermark_exceeded').to('healthy')
          .and change { high_watermark_exceeded_ready_index.reload.watermark_level }
            .from('high_watermark_exceeded').to('healthy')
          .and not_change { overprovisioned_pending_index.reload.watermark_level }
            .and not_change { healthy_index.reload.watermark_level }
      end

      context 'when update_reserved_storage_bytes! is raised on a record' do
        it 'does not raise an error' do
          allow(high_watermark_exceeded_pending_index).to receive(:update_reserved_storage_bytes!)
            .and_raise ActiveRecord::RecordNotUnique

          expect { consume_event(subscriber: described_class, event: event) }.not_to raise_error
        end
      end

      it 'processes records in batches' do
        stub_const("#{described_class}::BATCH_SIZE", 2)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 2)
        end

        consume_event(subscriber: described_class, event: event)

        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 1)
        end

        consume_event(subscriber: described_class, event: event)
      end

      it 'logs metadata with number of indices updated' do
        expect_next_instance_of(described_class) do |instance|
          expect(instance).to receive(:log_extra_metadata_on_done).with(:indices_updated_count, 3)
        end

        consume_event(subscriber: described_class, event: event)
      end
    end
  end
end
