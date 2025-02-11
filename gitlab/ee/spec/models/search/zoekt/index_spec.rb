# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::Index, feature_category: :global_search do
  let_it_be(:namespace) { create(:group) }
  let_it_be_with_reload(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: namespace) }
  let_it_be(:zoekt_node) { create(:zoekt_node) }
  let_it_be(:zoekt_replica) { create(:zoekt_replica, zoekt_enabled_namespace: zoekt_enabled_namespace) }
  let_it_be_with_refind(:zoekt_index) do
    create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: zoekt_node, replica: zoekt_replica,
      reserved_storage_bytes: 100.megabytes)
  end

  subject { zoekt_index }

  describe 'relations' do
    it { is_expected.to belong_to(:zoekt_enabled_namespace).inverse_of(:indices) }
    it { is_expected.to belong_to(:node).inverse_of(:indices) }
    it { is_expected.to belong_to(:replica).inverse_of(:indices) }
    it { is_expected.to have_many(:zoekt_repositories).inverse_of(:zoekt_index) }

    it 'restricts deletion when there are associated zoekt repositories' do
      project = create(:project, namespace_id: zoekt_index.namespace_id)
      repo = zoekt_index.zoekt_repositories.create!(project: project, state: :pending)

      expect(zoekt_index.zoekt_repositories).to match_array([repo])
      expect { zoekt_index.destroy! }.to raise_error ActiveRecord::InvalidForeignKey

      repo.destroy!

      expect { zoekt_index.destroy! }.not_to raise_error
    end
  end

  it { expect(described_class.new.reserved_storage_bytes).to eq 10.gigabytes }

  describe 'validations' do
    it 'validates that zoekt_enabled_namespace root_namespace_id matches namespace_id' do
      zoekt_index = described_class.new(zoekt_enabled_namespace: zoekt_enabled_namespace,
        node: zoekt_node, namespace_id: 0)
      expect(zoekt_index).to be_invalid
    end

    it { expect(described_class).to validate_jsonb_schema(['zoekt_indices_metadata']) }

    it 'allows a project_id_to value in metadata to be either an integer or nil' do
      expect(described_class.new(metadata: { 'project_id_from' => 123, 'project_id_to' => 456 })).to be_valid
      expect(described_class.new(metadata: { 'project_id_from' => 123, 'project_id_to' => nil })).to be_valid
    end
  end

  describe 'callbacks' do
    describe '#destroy!' do
      it 'calls Search::Zoekt::NamespaceIndexerWorker for the namespace with delete operation' do
        expect(Search::Zoekt::NamespaceIndexerWorker).to receive(:perform_async)
          .with(zoekt_enabled_namespace.root_namespace_id, 'delete', zoekt_node.id)

        zoekt_index.destroy!
      end
    end
  end

  describe 'scopes' do
    let_it_be(:namespace_2) { create(:group) }
    let_it_be_with_reload(:zoekt_enabled_namespace_2) { create(:zoekt_enabled_namespace, namespace: namespace_2) }
    let_it_be(:node_2) { create(:zoekt_node) }
    let_it_be(:zoekt_index_2) do
      create(:zoekt_index, node: node_2, zoekt_enabled_namespace: zoekt_enabled_namespace_2)
    end

    before do
      create_list(:zoekt_repository, 5, zoekt_index: zoekt_index, size_bytes: 100.megabytes)
    end

    describe '.for_node' do
      subject { described_class.for_node(node_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }
    end

    describe '.for_root_namespace_id' do
      subject { described_class.for_root_namespace_id(namespace_2) }

      it { is_expected.to contain_exactly(zoekt_index_2) }

      context 'when there are orphaned indices' do
        before do
          zoekt_index_2.update!(zoekt_enabled_namespace: nil)
        end

        it { is_expected.to be_empty }
      end
    end

    describe '.for_root_namespace_id_with_search_enabled' do
      it 'correctly filters on the search field' do
        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to contain_exactly(zoekt_index_2)

        zoekt_enabled_namespace_2.update!(search: false)

        expect(described_class.for_root_namespace_id_with_search_enabled(namespace_2))
          .to be_empty
      end
    end

    describe '.with_all_finished_repositories' do
      let_it_be(:idx) { create(:zoekt_index) } # It has some pending and some ready zoekt_repositories
      let_it_be(:idx2) { create(:zoekt_index) } # It has all ready zoekt_repositories
      let_it_be(:idx3) { create(:zoekt_index) } # It does not have zoekt_repositories
      let_it_be(:idx4) { create(:zoekt_index) } # It has all failed zoekt_repositories
      let_it_be(:idx5) { create(:zoekt_index) } # It has some failed and some ready zoekt_repositories
      let_it_be(:idx6) { create(:zoekt_index) } # It has some initializing and some pending zoekt_repositories
      let_it_be(:idx_project) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx_project2) { create(:project, namespace_id: idx.namespace_id) }
      let_it_be(:idx2_project2) { create(:project, namespace_id: idx2.namespace_id) }
      let_it_be(:idx4_project) { create(:project, namespace_id: idx4.namespace_id) }
      let_it_be(:idx5_project) { create(:project, namespace_id: idx5.namespace_id) }
      let_it_be(:idx5_project2) { create(:project, namespace_id: idx5.namespace_id) }
      let_it_be(:idx6_project) { create(:project, namespace_id: idx6.namespace_id) }
      let_it_be(:idx6_project2) { create(:project, namespace_id: idx6.namespace_id) }

      before do
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project, state: :pending)
        idx.zoekt_repositories.create!(zoekt_index: idx, project: idx_project2, state: :ready)
        idx2.zoekt_repositories.create!(zoekt_index: idx2, project: idx2_project2, state: :ready)
        idx4.zoekt_repositories.create!(zoekt_index: idx2, project: idx4_project, state: :failed)
        idx5.zoekt_repositories.create!(zoekt_index: idx2, project: idx5_project, state: :failed)
        idx5.zoekt_repositories.create!(zoekt_index: idx2, project: idx5_project2, state: :ready)
        idx6.zoekt_repositories.create!(zoekt_index: idx6, project: idx6_project, state: :initializing)
        idx6.zoekt_repositories.create!(zoekt_index: idx6, project: idx6_project2, state: :pending)
      end

      it 'returns all the indices whose all zoekt_repositories are ready' do
        expect(described_class.with_all_finished_repositories).to include(idx2, idx3, idx4, idx5)
        expect(described_class.with_all_finished_repositories).not_to include(idx, idx6)
      end
    end

    describe '.ordered_by_used_storage_updated_at' do
      let_it_be(:zoekt_index_3) { create(:zoekt_index) }

      subject(:results) { described_class.ordered_by_used_storage_updated_at }

      it 'returns all indices in ascending order by used_storage_bytes_updated_at' do
        zoekt_index.update!(used_storage_bytes_updated_at: 10.minutes.ago)
        zoekt_index_2.update!(used_storage_bytes_updated_at: 5.hours.ago)
        zoekt_index_3.update!(used_storage_bytes_updated_at: 2.minutes.ago)
        expect(results.pluck(:id)).to eq([zoekt_index_2.id, zoekt_index.id, zoekt_index_3.id])
      end
    end

    describe '.with_stale_used_storage_bytes_updated_at' do
      let_it_be(:time) { Time.zone.now }
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_2) { create(:zoekt_index, :stale_used_storage_bytes_updated_at) }
      let_it_be(:idx_3) do
        create(:zoekt_index, used_storage_bytes_updated_at: time, last_indexed_at: time - 5.seconds)
      end

      subject(:results) { described_class.with_stale_used_storage_bytes_updated_at }

      it 'returns all the indices whose used_storage_bytes_updated_at is less than last_indexed_at' do
        expect(results).to include idx, idx_2
        expect(results).not_to include idx_3
      end
    end

    describe '.should_be_reserved_storage_bytes_adjusted' do
      let_it_be(:overprovisioned_pending) { create(:zoekt_index, :overprovisioned) }
      let_it_be(:overprovisioned_ready) { create(:zoekt_index, :overprovisioned, :ready) }
      let_it_be(:high_watermark_exceeded_pending) { create(:zoekt_index, :high_watermark_exceeded) }
      let_it_be(:high_watermark_exceeded_ready) { create(:zoekt_index, :high_watermark_exceeded, :ready) }
      let_it_be(:healthy) { create(:zoekt_index, :healthy) }

      subject(:scope) { described_class.should_be_reserved_storage_bytes_adjusted }

      it 'returns correct indices' do
        expect(scope).to include(overprovisioned_ready, high_watermark_exceeded_pending, high_watermark_exceeded_ready)
        expect(scope).not_to include(overprovisioned_pending, healthy)
      end
    end

    describe '.pre_ready' do
      let_it_be(:in_progress) { create(:zoekt_index, state: :in_progress) }
      let_it_be(:initializing) { create(:zoekt_index, state: :initializing) }
      let_it_be(:ready) { create(:zoekt_index, state: :ready) }
      let_it_be(:reallocating) { create(:zoekt_index, state: :reallocating) }
      let_it_be(:pending_deletion) { create(:zoekt_index, state: :pending_deletion) }

      it 'returns correct indices' do
        expect(described_class.pre_ready).to contain_exactly(zoekt_index, zoekt_index_2, in_progress, initializing)
      end
    end

    describe '.searchable' do
      let_it_be(:zoekt_index_ready) do
        create(:zoekt_index, node: zoekt_node, zoekt_enabled_namespace: zoekt_enabled_namespace_2, state: :ready)
      end

      it 'returns correct indices' do
        expect(described_class.searchable).to contain_exactly(zoekt_index_ready)
      end
    end

    describe '.preload_zoekt_enabled_namespace_and_namespace' do
      it 'preloads the project and avoids N+1 queries' do
        index = described_class.preload_zoekt_enabled_namespace_and_namespace.first
        recorder = ActiveRecord::QueryRecorder.new { index.zoekt_enabled_namespace.namespace }
        expect(recorder.count).to be_zero
      end
    end

    describe '.preload_node' do
      it 'preloads the node and avoids N+1 queries' do
        index = described_class.preload_node.first
        recorder = ActiveRecord::QueryRecorder.new { index.node }
        expect(recorder.count).to be_zero
      end
    end

    describe '.negative_reserved_storage_bytes' do
      let_it_be(:negative_reserved_storage_bytes_index) { create(:zoekt_index, :negative_reserved_storage_bytes) }

      it 'returns indices only with negative reserved_storage_bytes' do
        results = described_class.negative_reserved_storage_bytes
        expect(results.all? { |idx| idx.reserved_storage_bytes < 0 }).to be true
        expect(results).to include(negative_reserved_storage_bytes_index)
      end
    end

    describe '.should_be_marked_as_orphaned' do
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_missing_replica) { create(:zoekt_index) }
      let_it_be(:idx_missing_enabled_namespace) { create(:zoekt_index) }
      let_it_be(:idx_already_marked_as_orphaned) { create(:zoekt_index) }
      let_it_be(:zoekt_replica) { create(:zoekt_replica) }

      it 'returns indices that are missing either an enabled namespace or a replica' do
        idx_missing_replica.replica.destroy!
        idx_missing_enabled_namespace.zoekt_enabled_namespace.destroy!
        idx_already_marked_as_orphaned.replica.destroy!
        idx_already_marked_as_orphaned.orphaned!

        expect(described_class.should_be_marked_as_orphaned).to match_array([idx_missing_replica,
          idx_missing_enabled_namespace])
      end
    end

    describe '.should_be_deleted' do
      let_it_be(:idx) { create(:zoekt_index) }
      let_it_be(:idx_orphaned) { create(:zoekt_index, state: :orphaned) }
      let_it_be(:idx_pending_deletion) { create(:zoekt_index, state: :pending_deletion) }

      it 'returns indices that are marked as either orphaned or pending_deletion' do
        expect(described_class.should_be_deleted).to match_array([idx_orphaned, idx_pending_deletion])
      end
    end

    describe '.should_be_pending_eviction' do
      let_it_be(:idx_healthy) { create(:zoekt_index, :healthy) }
      let_it_be(:idx_critical_watermark_exceeded) { create(:zoekt_index, :critical_watermark_exceeded) }
      let_it_be(:idx_pending_eviction) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :pending_eviction)
      end

      let_it_be(:idx_evicted) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :evicted)
      end

      let_it_be(:idx_orphaned) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :orphaned)
      end

      let_it_be(:idx_pending_deletion) do
        create(:zoekt_index, :critical_watermark_exceeded, state: :pending_deletion)
      end

      it 'returns indices that are idx_critical_watermark_exceeded that contain zoekt_replica_id' do
        expect(described_class.should_be_pending_eviction).to match_array([idx_critical_watermark_exceeded])
      end
    end

    describe '.with_mismatched_watermark_levels' do
      let(:ideal_percent) { Search::Zoekt::Index::STORAGE_IDEAL_PERCENT_USED }
      let(:low_watermark) { Search::Zoekt::Index::STORAGE_LOW_WATERMARK }
      let(:high_watermark) { Search::Zoekt::Index::STORAGE_HIGH_WATERMARK }
      let(:critical_watermark) { Search::Zoekt::Index::STORAGE_CRITICAL_WATERMARK }
      let(:mismatched_indices) { described_class.with_mismatched_watermark_levels }

      before do
        # Clear existing records
        Search::Zoekt::Repository.delete_all
        described_class.delete_all
      end

      it 'returns indices where watermark_level is mismatched (healthy)' do
        # Setup a healthy record but with incorrect watermark_level
        create(
          :zoekt_index,
          used_storage_bytes: 40,
          reserved_storage_bytes: 100,
          watermark_level: :low_watermark_exceeded # Incorrect level
        )

        expect(mismatched_indices.count).to eq(1)
        expect(mismatched_indices.first.watermark_level).to eq('low_watermark_exceeded')
      end

      it 'returns no indices when all watermark_levels are correct' do
        # Setup record with correct watermark level
        create(
          :zoekt_index,
          used_storage_bytes: 40,
          reserved_storage_bytes: 100,
          watermark_level: :healthy
        )

        expect(mismatched_indices).to be_empty
      end

      it 'detects overprovisioned mismatches' do
        # Setup an overprovisioned record with incorrect watermark_level
        create(
          :zoekt_index,
          used_storage_bytes: 10,
          reserved_storage_bytes: 100,
          watermark_level: :healthy # Incorrect level
        )

        expect(mismatched_indices.count).to eq(1)
        expect(mismatched_indices.first.watermark_level).to eq('healthy')
      end

      it 'handles edge cases at the exact boundary' do
        # Setup a record exactly at the STORAGE_LOW_WATERMARK
        create(
          :zoekt_index,
          used_storage_bytes: (low_watermark * 100).to_i,
          reserved_storage_bytes: 100,
          watermark_level: :healthy
        )

        expect(mismatched_indices.count).to eq(1)
        expect(mismatched_indices.first.watermark_level).to eq('healthy')
      end

      it 'handles division by zero gracefully' do
        # Setup a record with zero reserved_storage_bytes
        create(
          :zoekt_index,
          used_storage_bytes: 50,
          reserved_storage_bytes: 0,
          watermark_level: :critical_watermark_exceeded
        )

        expect { mismatched_indices }.not_to raise_error
      end

      it 'returns indices where watermark_level is mismatched (critical)' do
        # Setup a record that should be critical but has incorrect watermark_level
        create(
          :zoekt_index,
          used_storage_bytes: (critical_watermark * 100) + 1,
          reserved_storage_bytes: 100,
          watermark_level: :high_watermark_exceeded # Incorrect level
        )

        expect(mismatched_indices.count).to eq(1)
        expect(mismatched_indices.first.watermark_level).to eq('high_watermark_exceeded')
      end

      it 'correctly identifies critical watermark level' do
        # Setup a record with correct critical watermark level
        create(
          :zoekt_index,
          used_storage_bytes: (critical_watermark * 100) + 1,
          reserved_storage_bytes: 100,
          watermark_level: :critical_watermark_exceeded
        )

        expect(mismatched_indices).to be_empty
      end
    end
  end

  describe '#update_reserved_storage_bytes!' do
    let_it_be(:zoekt_node) { create(:zoekt_node, total_bytes: 100_000) }
    let_it_be_with_reload(:idx) do
      create(:zoekt_index, used_storage_bytes: 90, reserved_storage_bytes: 100, node: zoekt_node)
    end

    it 'updates indices with the sum of size_bytes for all associated repositories' do
      ideal_reserved_storage = idx.used_storage_bytes / described_class::STORAGE_IDEAL_PERCENT_USED

      expect do
        idx.update_reserved_storage_bytes!
      end.to change {
        idx.reload.reserved_storage_bytes
      }.from(100).to(ideal_reserved_storage)

      expect(
        idx.used_storage_bytes / idx.reserved_storage_bytes.to_f
      ).to eq(described_class::STORAGE_IDEAL_PERCENT_USED)
    end

    describe 'updates the watermark level to the appropriate state' do
      let(:percent_used) { 0 }

      before do
        idx.high_watermark_exceeded!
        allow(idx).to receive(:storage_percent_used).and_return(percent_used)
      end

      context 'when index should be marked as overprovisioned' do
        let(:percent_used) { 0.01 }

        it 'updates the watermark level to the appropriate state' do
          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("high_watermark_exceeded").to("overprovisioned")
        end
      end

      context 'when index should be marked as healthy' do
        let(:percent_used) { described_class::STORAGE_IDEAL_PERCENT_USED }

        it 'updates the watermark level to the appropriate state' do
          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("high_watermark_exceeded").to("healthy")
        end
      end

      context 'when index should be marked as low_watermark_exceeded' do
        let(:percent_used) { described_class::STORAGE_LOW_WATERMARK }

        it 'updates the watermark level to the appropriate state' do
          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("high_watermark_exceeded").to("low_watermark_exceeded")
        end
      end

      context 'when index should be marked as high_watermark_exceeded' do
        let(:percent_used) { described_class::STORAGE_HIGH_WATERMARK }

        it 'updates the watermark level to the appropriate state' do
          idx.low_watermark_exceeded!

          expect { idx.update_reserved_storage_bytes! }.to change {
            idx.reload.watermark_level
          }.from("low_watermark_exceeded").to("high_watermark_exceeded")
        end
      end
    end

    context 'when the node only has a little bit more storage' do
      let_it_be(:zoekt_node) { create(:zoekt_node, total_bytes: 102, used_bytes: 0) }

      let_it_be(:idx) do
        create(:zoekt_index, used_storage_bytes: 90, reserved_storage_bytes: 100, node: zoekt_node)
      end

      it 'increases the node reservation as much as possible' do
        expect do
          idx.update_reserved_storage_bytes!
        end.to change {
          idx.reload.reserved_storage_bytes
        }.from(100).to(102)
      end
    end

    context 'when the node does not have any more storage' do
      let_it_be(:zoekt_node) { create(:zoekt_node, total_bytes: 100, used_bytes: 0) }

      let_it_be(:idx) do
        create(:zoekt_index, used_storage_bytes: 90, reserved_storage_bytes: 100, node: zoekt_node)
      end

      it 'does not do anything' do
        expect do
          idx.update_reserved_storage_bytes!
        end.not_to change {
          idx.reload.reserved_storage_bytes
        }
      end
    end

    context 'when an exception occurs' do
      it 'logs the error and re-raises the exception' do
        stubbed_logger = instance_double(::Search::Zoekt::Logger)
        expect(::Search::Zoekt::Logger).to receive(:build).and_return stubbed_logger

        expect(stubbed_logger).to receive(:error).with({
          class: 'Search::Zoekt::Index',
          message: 'Error attempting to update reserved_storage_bytes',
          error: 'Record invalid',
          new_reserved_bytes: anything,
          reserved_storage_bytes: anything,
          index_id: idx.id
        }.with_indifferent_access)

        expect(idx).to receive(:save!).and_raise ActiveRecord::RecordInvalid

        expect { idx.update_reserved_storage_bytes! }.to raise_error ActiveRecord::RecordInvalid
      end
    end

    context 'when used_storage_bytes is 0' do
      let_it_be(:index) { create(:zoekt_index, used_storage_bytes: 0) }

      it 'sets reserved_storage_bytes to DEFAULT_RESERVED_STORAGE_BYTES and watermark_level to overprovisioned' do
        index.update_reserved_storage_bytes!
        expect(index.reload.reserved_storage_bytes).to eq described_class::DEFAULT_RESERVED_STORAGE_BYTES
        expect(index).to be_overprovisioned
      end
    end
  end

  describe '#free_storage_bytes' do
    it 'is difference between reserved bytes and used bytes' do
      allow(zoekt_index).to receive_messages(reserved_storage_bytes: 100, used_storage_bytes: 1)
      expect(zoekt_index.free_storage_bytes).to eq(99)
    end
  end

  describe '#should_be_deleted?' do
    it 'returns true if the index state is orphaned or pending_deletion' do
      expect(zoekt_index).not_to be_should_be_deleted

      zoekt_index.state = :orphaned
      expect(zoekt_index).to be_should_be_deleted

      zoekt_index.state = :pending_deletion
      expect(zoekt_index).to be_should_be_deleted

      zoekt_index.state = :ready
      expect(zoekt_index).not_to be_should_be_deleted
    end
  end

  describe '#find_or_create_repository_by_project!' do
    let_it_be(:zoekt_index) { create(:zoekt_index) }
    let_it_be(:project) { create(:project) }

    context 'when find_or_create_by! raises an error' do
      before do
        allow(zoekt_index).to receive_message_chain(:zoekt_repositories, :find_or_create_by!).and_raise(StandardError)
      end

      it 'raises the error' do
        expect do
          zoekt_index.find_or_create_repository_by_project!(project.id, project)
        end.to raise_error(StandardError).and not_change { Search::Zoekt::Repository.count }
      end
    end

    context 'when zoekt_repository exists with the given params' do
      before do
        create(:zoekt_repository, project: project, zoekt_index: zoekt_index)
      end

      it 'returns the existing record' do
        result = nil
        expect do
          result = zoekt_index.find_or_create_repository_by_project!(project.id, project)
        end.not_to change { zoekt_index.zoekt_repositories.count }
        expect(result.project_identifier).to eq project.id
      end
    end

    context 'when zoekt_repository does not exists with the given params' do
      it 'creates and return the new record' do
        result = nil
        expect do
          result = zoekt_index.find_or_create_repository_by_project!(project.id, project)
        end.to change { zoekt_index.zoekt_repositories.count }.by(1)
        expect(result.project_identifier).to eq project.id
      end
    end
  end
end
