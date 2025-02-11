# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Widgets::Weight, feature_category: :team_planning do
  describe '.quick_action_params' do
    subject { described_class.quick_action_params }

    it { is_expected.to include(:weight) }
  end

  context 'with weight widget definition' do
    let_it_be(:work_item, refind: true) { create(:work_item, :issue, weight: 5) }

    before_all do
      WorkItems::WidgetDefinition.delete_all
    end

    before do
      create(
        :widget_definition,
        work_item_type: work_item.work_item_type, widget_type: 'weight',
        widget_options: widget_options
      )
    end

    describe '#weight' do
      subject(:weight) { work_item.get_widget(:weight).weight }

      context 'when work item does not support editable weight' do
        let(:widget_options) { { editable: false, rollup: false } }

        it 'returns nil' do
          expect(weight).to be_nil
        end
      end

      context 'when work item supports editable weight' do
        let(:widget_options) { { editable: true, rollup: false } }

        it 'returns the work item weight value' do
          expect(weight).to eq(work_item.weight)
        end
      end
    end

    describe 'rolled up values' do
      let(:rolled_up_weight) { work_item.get_widget(:weight).rolled_up_weight }
      let(:rolled_up_completed_weight) { work_item.get_widget(:weight).rolled_up_completed_weight }

      let_it_be(:group) { create(:group) }
      let_it_be(:project) { create(:project, group: group) }
      let_it_be(:work_item, refind: true) { create(:work_item, :epic, namespace: group) }

      let_it_be(:direct_child_issue) { create(:work_item, :issue, project: project, weight: 2) }
      let_it_be(:direct_child_issue_2) { create(:work_item, :issue, project: project, weight: 3) }
      let_it_be(:sub_epic) { create(:work_item, :epic, namespace: group) }
      let_it_be(:sub_epic_issue) { create(:work_item, :issue, project: project, weight: 5) }
      let_it_be(:sub_epic_issue_task) { create(:work_item, :task, project: project, weight: 1) }

      before_all do
        create(:parent_link, work_item_parent: work_item, work_item: direct_child_issue)
        create(:parent_link, work_item_parent: work_item, work_item: direct_child_issue_2)
        create(:parent_link, work_item_parent: work_item, work_item: sub_epic)
        create(:parent_link, work_item_parent: sub_epic, work_item: sub_epic_issue)
        create(:parent_link, work_item_parent: sub_epic_issue, work_item: sub_epic_issue_task)
      end

      context 'when work item does not support rolled up weight' do
        let(:widget_options) { { editable: false, rollup: false } }

        it 'returns nil' do
          expect(rolled_up_weight).to be_nil
          expect(rolled_up_completed_weight).to be_nil
        end
      end

      context 'when work item supports rolled up weight' do
        let(:widget_options) { { editable: false, rollup: true } }

        it 'returns the sum of all descendant issue weights' do
          expect(rolled_up_weight).to eq(10)
          expect(rolled_up_completed_weight).to eq(0)
        end

        context 'when work item has no descendants' do
          before do
            WorkItems::ParentLink.delete_all
          end

          it 'returns nil' do
            expect(rolled_up_weight).to be_nil
            expect(rolled_up_completed_weight).to be_nil
          end
        end

        context 'when descendant issues have no weight set' do
          before do
            WorkItem.id_in([direct_child_issue, direct_child_issue_2, sub_epic_issue]).update_all(weight: nil)
          end

          it 'returns nil' do
            expect(rolled_up_weight).to be_nil
            expect(rolled_up_completed_weight).to be_nil
          end
        end

        context 'when some descendant issues are closed' do
          before do
            direct_child_issue.close!
            sub_epic_issue.close!
          end

          it 'returns the sum of closed issue weights' do
            expect(rolled_up_weight).to eq(10)
            expect(rolled_up_completed_weight).to eq(7)
          end
        end
      end
    end
  end
end
