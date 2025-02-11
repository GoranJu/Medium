# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::RepoMarkedAsToDeleteEventWorker, :zoekt_settings_enabled, feature_category: :global_search do
  let(:event) { Search::Zoekt::RepoMarkedAsToDeleteEvent.new(data: data) }
  let_it_be_with_reload(:repos) { create_list(:zoekt_repository, 3, :orphaned) }
  let(:scope) { Search::Zoekt::Repository.all }
  let(:data) { {} }

  it_behaves_like 'subscribes to event'

  it 'has the `until_executed` deduplicate strategy' do
    expect(described_class.get_deduplicate_strategy).to eq(:until_executed)
  end

  it_behaves_like 'an idempotent worker' do
    it 'creates a delete repo task for all repos in the list' do
      expect(Search::Zoekt::Repository).to receive(:should_be_deleted).and_call_original
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(0).to(repos.size)
    end

    it 'processes in batches' do
      stub_const("#{described_class}::BATCH_SIZE", 2)
      expect(Search::Zoekt::Repository).to receive(:should_be_deleted).and_call_original
      expect do
        consume_event(subscriber: described_class, event: event)
      end.to change { Search::Zoekt::Task.where(task_type: :delete_repo).size }.from(0).to(described_class::BATCH_SIZE)
    end
  end
end
