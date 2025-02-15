# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EventFilter do
  describe '#apply_filter' do
    let_it_be(:group) { create(:group, :public) }
    let_it_be(:project) { create(:project, :public) }
    let_it_be(:epic) { create(:epic, group: group) }
    let_it_be(:issue_event) { create(:event, :created, project: project, target: create(:issue, project: project)) }
    let_it_be(:epic_event) { create(:event, :created, group: group, project: nil, target: epic) }
    let_it_be(:epic_work_item_event) do
      create(:event, :closed, group: group, project: nil, target_id: epic.work_item.id, target_type: 'WorkItem')
    end

    let(:filtered_events) { described_class.new(filter).apply_filter(Event.all) }

    context 'with the "epic" filter' do
      let(:filter) { described_class::EPIC }

      it 'filters issue events only' do
        expect(filtered_events).to contain_exactly(epic_event, epic_work_item_event)
      end
    end
  end
end
