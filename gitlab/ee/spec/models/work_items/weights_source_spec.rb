# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::WeightsSource, feature_category: :team_planning do
  subject(:work_item_weights_source) { build(:work_item_weights_source) }

  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:work_item) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:work_item) }

    describe '#copy_namespace_from_work_item' do
      let(:work_item) { create(:work_item) }

      it 'copies namespace_id from the associated work item' do
        expect do
          work_item_weights_source.work_item = work_item
          work_item_weights_source.valid?
        end.to change { work_item_weights_source.namespace_id }.from(nil).to(work_item.namespace_id)
      end
    end
  end

  describe '.upsert_rolled_up_weights_for' do
    let_it_be(:group) { create(:group) }
    let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

    let_it_be_with_reload(:children) do
      create_list(:work_item, 4, :issue, namespace: group).each do |child|
        create(:parent_link, work_item: child, work_item_parent: work_item)
      end
    end

    context 'with various children weights' do
      before do
        children[0].update!(weight: 3)
        children[1].update!(weight: 4, state: :closed)

        # Rolled up weights will be counted and set weight will be ignored
        children[2].update!(weight: 10)
        create(:work_item_weights_source, work_item: children[2], rolled_up_weight: 5, rolled_up_completed_weight: 1)

        # rolled_up_weight will be counted as completed because this is closed
        children[3].update!(weight: nil, state: :closed)
        create(:work_item_weights_source, work_item: children[3], rolled_up_weight: 7, rolled_up_completed_weight: 2)
      end

      it 'inserts the correct rolled up weights for the parent work item' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 19,
          rolled_up_completed_weight: 12
        )
      end

      context 'when existing weight sources record exists' do
        before_all do
          create(:work_item_weights_source, work_item: work_item, rolled_up_weight: 99, rolled_up_completed_weight: 99)
        end

        it 'updates the existing record' do
          expect { described_class.upsert_rolled_up_weights_for(work_item) }
            .to change { work_item.weights_source.reload.rolled_up_weight }.from(99).to(19)
            .and change { work_item.weights_source.reload.rolled_up_completed_weight }.from(99).to(12)
        end

        context 'when all children are removed' do
          before do
            WorkItems::ParentLink.delete_all
          end

          it 'sets null rolled up weights' do
            expect { described_class.upsert_rolled_up_weights_for(work_item) }
              .to change { work_item.weights_source.reload.rolled_up_weight }.from(99).to(nil)
              .and change { work_item.weights_source.reload.rolled_up_completed_weight }.from(99).to(nil)
          end
        end
      end
    end

    context 'when children have set weights' do
      before do
        children[0].update!(weight: 1)
        children[1].update!(weight: 2)
        children[2].update!(weight: 3, state: :closed)
        children[3].update!(weight: 4, state: :closed)
      end

      it 'computes the rolled up values from the set weights' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 10,
          rolled_up_completed_weight: 7
        )
      end
    end

    context 'when children have rolled up weights' do
      before do
        create(:work_item_weights_source, work_item: children[0], rolled_up_weight: 1, rolled_up_completed_weight: 1)
        create(:work_item_weights_source, work_item: children[1], rolled_up_weight: 2, rolled_up_completed_weight: 1)
        create(:work_item_weights_source, work_item: children[2], rolled_up_weight: 3, rolled_up_completed_weight: 1)

        # When work item is closed, we count the total weight of 4 as completed even if it has some open descendants.
        children[3].update!(state: :closed)
        create(:work_item_weights_source, work_item: children[3], rolled_up_weight: 4, rolled_up_completed_weight: 1)
      end

      it 'computes the rolled up values from the rolled up values of the children' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 10,
          rolled_up_completed_weight: 7
        )
      end
    end

    context 'when a child has set weight and rolled up weights' do
      before do
        children[0].update!(weight: 5)
        create(:work_item_weights_source, work_item: children[0], rolled_up_weight: 2, rolled_up_completed_weight: 1)
      end

      it 'prioritizes the rolled up weight over the set weight' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: 2,
          rolled_up_completed_weight: 1
        )
      end

      context 'when child is closed' do
        before do
          children[0].update!(state: :closed)
        end

        it 'counts the full rolled up weight as completed' do
          described_class.upsert_rolled_up_weights_for(work_item)

          expect(work_item.weights_source.reload).to have_attributes(
            rolled_up_weight: 2,
            rolled_up_completed_weight: 2
          )
        end
      end
    end

    context 'when children have no weights and existing record exists' do
      before do
        create(:work_item_weights_source, work_item: work_item, rolled_up_weight: 99, rolled_up_completed_weight: 99)
      end

      it 'updates the recoord with null weights' do
        described_class.upsert_rolled_up_weights_for(work_item)

        expect(work_item.weights_source.reload).to have_attributes(
          rolled_up_weight: nil,
          rolled_up_completed_weight: nil
        )
      end
    end

    context 'when work item is not persisted' do
      it 'returns nil' do
        expect(described_class.upsert_rolled_up_weights_for(build(:work_item))).to be_nil
      end
    end
  end
end
