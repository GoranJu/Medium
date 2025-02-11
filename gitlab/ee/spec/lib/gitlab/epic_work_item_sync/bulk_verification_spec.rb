# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::EpicWorkItemSync::BulkVerification, feature_category: :team_planning do
  describe '#verify' do
    let_it_be(:group) { create(:group) }
    let(:attributes) { %w[title description] }

    let(:verification) { described_class.new(filter_attributes: attributes) }

    subject(:verify) { verification.verify }

    context 'when there are no epics with work items' do
      it 'returns an empty hash' do
        expect(verify).to include({ valid: 0, mismatched: 0 })
      end
    end

    context 'when there are epics with work items' do
      let_it_be(:epics) { create_list(:epic, 3, group: group) }

      it 'avoids N+1 queries' do
        control = ActiveRecord::QueryRecorder.new(skip_cached: false) do
          verification.verify
        end

        create_list(:epic, 2, group: group)

        expect do
          verification.verify
        end.not_to exceed_all_query_limit(control.count + 4) # related epic links can't be preloaded
      end

      context 'when there are mismatches' do
        before do
          stub_const('Gitlab::EpicWorkItemSync::BulkVerification::BATCH_SIZE', 2)

          allow_next_instance_of(Gitlab::EpicWorkItemSync::Diff) do |instance|
            allow(instance).to receive(:attributes).and_return([])
          end

          allow_next_instance_of(Gitlab::EpicWorkItemSync::Diff, epics.first, epics.first.work_item) do |instance|
            allow(instance).to receive(:attributes).and_return(mismatched_attributes)
          end
        end

        context 'when mismatched attributes match attributes we check for' do
          let(:mismatched_attributes) { %w[title] }

          it 'returns mismatched amount and logs the mismatches',
            quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/505417' do
            expect_next_instance_of(Gitlab::EpicWorkItemSync::Diff) do |instance|
              expect(instance).to receive(:attributes).once.and_return(mismatched_attributes)
            end

            expect(Gitlab::EpicWorkItemSync::Logger).to receive(:warn).with(
              epic_id: epics.first.id,
              work_item_id: epics.first.work_item.id,
              mismatching_attributes: include("title")
            )

            expect(verify).to include({ valid: 2, mismatched: 1 })
          end

          it 'yields the progress' do
            expect do |b|
              verification.verify(&b)
            end.to yield_successive_args(
              a_hash_including({ valid: 1, mismatched: 1 }),
              a_hash_including({ valid: 2, mismatched: 1 })
            )
          end
        end

        context 'when mismatched attributes do not match attributes we check for' do
          let(:mismatched_attributes) { %w[relative_position] }

          it { is_expected.to include({ valid: 3, mismatched: 0 }) }
        end
      end

      context 'when there are no mismatches' do
        before do
          stub_const('Gitlab::EpicWorkItemSync::BulkVerification::BATCH_SIZE', 2)

          allow_next_instance_of(Gitlab::EpicWorkItemSync::Diff) do |instance|
            allow(instance).to receive(:attributes).and_return([])
          end
        end

        it { is_expected.to include({ valid: 3, mismatched: 0 }) }
      end
    end
  end
end
