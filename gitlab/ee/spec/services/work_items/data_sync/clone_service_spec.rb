# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::CloneService, feature_category: :team_planning do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group) }
  let_it_be(:target_group) { create(:group, parent: parent_group) }
  let_it_be(:original_work_item) { create(:work_item, :group_level, namespace: group) }
  let_it_be(:source_namespace_member) { create(:user, reporter_of: group) }
  let_it_be(:target_namespace_member) { create(:user, reporter_of: target_group) }
  let_it_be(:namespaces_member) { create(:user, developer_of: [group, target_group]) }

  let_it_be_with_refind(:target_namespace) { target_group }

  let(:service) do
    described_class.new(
      work_item: original_work_item,
      target_namespace: target_namespace,
      current_user: current_user
    )
  end

  before do
    stub_licensed_features(epics: true)
  end

  context 'when user does not have permissions' do
    context 'when user cannot read original work item' do
      let_it_be(:current_user) { target_namespace_member }

      it_behaves_like 'fails to transfer work item', 'Cannot clone work item due to insufficient permissions'
    end

    context 'when user cannot create work items in target namespace' do
      let_it_be(:current_user) { source_namespace_member }

      it_behaves_like 'fails to transfer work item', 'Cannot clone work item due to insufficient permissions'
    end
  end

  context 'when user has permission to clone work item' do
    let_it_be(:current_user) { namespaces_member }

    context 'without group level work item license' do
      before do
        stub_licensed_features(epics: false)
      end

      it_behaves_like 'fails to transfer work item', 'Cannot clone work item due to insufficient permissions'
    end

    context 'when cloning to a pending delete group' do
      before do
        create(:group_deletion_schedule,
          group: target_namespace,
          marked_for_deletion_on: 5.days.from_now,
          deleting_user: current_user
        )
      end

      after do
        target_namespace.deletion_schedule.destroy!
      end

      it_behaves_like 'fails to transfer work item',
        'Cannot clone work item to target namespace as it is pending deletion'
    end

    context 'when cloning work item with success', :freeze_time do
      let(:expected_original_work_item_state) { Issue.available_states[:opened] }

      let(:service_desk_alias_address) do
        ::ServiceDesk::Emails.new(target_namespace.project).alias_address if target_namespace.respond_to?(:project)
      end

      let!(:original_work_item_attrs) do
        {
          project: target_namespace.try(:project),
          namespace: target_namespace,
          work_item_type: original_work_item.work_item_type,
          author: current_user,
          title: original_work_item.title,
          description: original_work_item.description,
          state_id: Issue.available_states[:opened],
          created_at: Time.current,
          updated_at: Time.current,
          confidential: original_work_item.confidential,
          cached_markdown_version: original_work_item.cached_markdown_version,
          lock_version: original_work_item.lock_version,
          imported_from: "none",
          updated_by: current_user,
          last_edited_at: nil,
          last_edited_by: nil,
          closed_at: nil,
          closed_by: nil,
          duplicated_to_id: nil,
          moved_to_id: nil,
          promoted_to_epic_id: nil,
          external_key: nil,
          upvotes_count: 0,
          blocking_issues_count: 0,
          service_desk_reply_to: service_desk_alias_address
        }
      end

      it_behaves_like 'cloneable and moveable work item'
      it_behaves_like 'cloneable and moveable widget data'
      it_behaves_like 'cloneable and moveable for ee widget data'

      context 'with epic work item' do
        let_it_be_with_reload(:original_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

        before do
          allow(original_work_item).to receive(:supports_move_and_clone?).and_return(true)
        end

        it_behaves_like 'cloneable and moveable work item'
        it_behaves_like 'cloneable and moveable widget data'
        it_behaves_like 'cloneable and moveable for ee widget data'
      end
    end
  end
end
