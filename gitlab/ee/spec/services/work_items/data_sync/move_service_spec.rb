# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::DataSync::MoveService, feature_category: :team_planning do
  let_it_be(:parent_group) { create(:group) }
  let_it_be(:group) { create(:group) }
  let_it_be(:target_group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, group: target_group) }
  let_it_be_with_reload(:original_work_item) { create(:work_item, :group_level, namespace: group) }
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

      it_behaves_like 'fails to transfer work item', 'Cannot move work item due to insufficient permissions'
    end

    context 'when user cannot create work items in target namespace' do
      let_it_be(:current_user) { source_namespace_member }

      it_behaves_like 'fails to transfer work item', 'Cannot move work item due to insufficient permissions'
    end
  end

  context 'when user has permission to move work item' do
    let_it_be(:current_user) { namespaces_member }

    context 'when moving a group level work item to same group' do
      let(:target_namespace) { group }

      it_behaves_like 'fails to transfer work item', 'Cannot move work item to same project or group it originates from'
    end

    context 'when moving group level work item to a project' do
      let(:target_namespace) { project }

      it_behaves_like 'fails to transfer work item', 'Cannot move work item between Projects and Groups'
    end

    context 'when moving group level work item to a project namespace' do
      let_it_be(:target_namespace) { project.project_namespace }

      it_behaves_like 'fails to transfer work item', 'Cannot move work item between Projects and Groups'
    end

    context 'without group level work item license' do
      before do
        stub_licensed_features(epics: false)
      end

      it_behaves_like 'fails to transfer work item', 'Cannot move work item due to insufficient permissions'
    end

    context 'when moving to a pending delete group' do
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
        'Cannot move work item to target namespace as it is pending deletion'
    end

    context 'when cloning work item with success', :freeze_time do
      let(:expected_original_work_item_state) { Issue.available_states[:closed] }

      let(:service_desk_alias_address) do
        ::ServiceDesk::Emails.new(target_namespace.project).alias_address if target_namespace.respond_to?(:project)
      end

      let!(:original_work_item_attrs) do
        {
          project: target_namespace.try(:project),
          namespace: target_namespace,
          work_item_type: original_work_item.work_item_type,
          author: original_work_item.author,
          title: original_work_item.title,
          description: original_work_item.description,
          state_id: original_work_item.state_id,
          created_at: original_work_item.reload.created_at,
          updated_by: original_work_item.updated_by,
          updated_at: original_work_item.reload.updated_at,
          confidential: original_work_item.confidential,
          cached_markdown_version: original_work_item.cached_markdown_version,
          lock_version: original_work_item.lock_version,
          imported_from: "none",
          last_edited_at: original_work_item.last_edited_at,
          last_edited_by: original_work_item.last_edited_by,
          closed_at: original_work_item.closed_at,
          closed_by: original_work_item.closed_by,
          duplicated_to_id: original_work_item.duplicated_to_id,
          moved_to_id: original_work_item.moved_to_id,
          promoted_to_epic_id: original_work_item.promoted_to_epic_id,
          external_key: original_work_item.external_key,
          upvotes_count: original_work_item.upvotes_count,
          blocking_issues_count: original_work_item.blocking_issues_count,
          service_desk_reply_to: service_desk_alias_address
        }
      end

      it_behaves_like 'cloneable and moveable work item'

      context 'when cleanup original data is enabled' do
        before do
          stub_feature_flags(cleanup_data_source_work_item_data: true)
        end

        it_behaves_like 'cloneable and moveable widget data'
        it_behaves_like 'cloneable and moveable for ee widget data'
      end

      context 'when cleanup original data is disabled' do
        before do
          stub_feature_flags(cleanup_data_source_work_item_data: false)
        end

        it_behaves_like 'cloneable and moveable widget data'
        it_behaves_like 'cloneable and moveable for ee widget data'
      end

      context 'with epic work item' do
        let_it_be_with_reload(:original_work_item) { create(:work_item, :epic_with_legacy_epic, namespace: group) }

        before do
          allow(original_work_item).to receive(:supports_move_and_clone?).and_return(true)
        end

        it_behaves_like 'cloneable and moveable work item'

        context 'when cleanup original data is enabled' do
          before do
            stub_feature_flags(cleanup_data_source_work_item_data: true)
          end

          it_behaves_like 'cloneable and moveable widget data'
          it_behaves_like 'cloneable and moveable for ee widget data'
        end

        context 'when cleanup original data is disabled' do
          before do
            stub_feature_flags(cleanup_data_source_work_item_data: false)
          end

          it_behaves_like 'cloneable and moveable widget data'
          it_behaves_like 'cloneable and moveable for ee widget data'
        end
      end
    end
  end
end
