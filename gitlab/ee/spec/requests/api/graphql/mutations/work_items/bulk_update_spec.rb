# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Bulk update work items', feature_category: :team_planning do
  include GraphqlHelpers

  let_it_be(:developer) { create(:user) }
  let_it_be(:private_group) { create(:group, :private) }
  let_it_be(:parent_group) { create(:group, developers: developer) }
  let_it_be(:group) { create(:group, parent: parent_group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:label1) { create(:group_label, group: parent_group) }
  let_it_be(:label2) { create(:group_label, group: parent_group) }
  let_it_be(:label3) { create(:group_label, group: private_group) }
  let_it_be_with_reload(:work_item1) { create(:work_item, :group_level, namespace: group, labels: [label1]) }
  let_it_be_with_reload(:work_item2) { create(:work_item, project: project, labels: [label1]) }
  let_it_be_with_reload(:work_item3) { create(:work_item, :group_level, namespace: parent_group, labels: [label1]) }
  let_it_be_with_reload(:work_item4) { create(:work_item, :group_level, namespace: private_group, labels: [label3]) }

  let(:mutation) { graphql_mutation(:work_item_bulk_update, base_arguments.merge(widget_arguments)) }
  let(:mutation_response) { graphql_mutation_response(:work_item_bulk_update) }
  let(:current_user) { developer }
  let(:work_item_ids) { [work_item1, work_item2, work_item3, work_item4].map { |work_item| work_item.to_gid.to_s } }
  let(:base_arguments) { { parent_id: parent.to_gid.to_s, ids: work_item_ids } }

  let(:widget_arguments) do
    {
      labels_widget: {
        add_label_ids: [label2.to_gid.to_s],
        remove_label_ids: [label1.to_gid.to_s, label3.to_gid.to_s]
      }
    }
  end

  context 'when user can update all issues' do
    context 'when scoping to a parent group' do
      let(:parent) { group }

      context 'when group_bulk_edit feature is available' do
        before do
          stub_licensed_features(epics: true, group_bulk_edit: true)
        end

        it 'updates only specified work items that belong to the group hierarchy' do
          expect do
            post_graphql_mutation(mutation, current_user: current_user)
          end.to change { work_item1.reload.label_ids }.from([label1.id]).to([label2.id])
            .and change { work_item2.reload.label_ids }.from([label1.id]).to([label2.id])
            .and not_change { work_item3.reload.label_ids }.from([label1.id])
            .and not_change { work_item4.reload.label_ids }.from([label3.id])
        end

        context 'when current user cannot read the specified group' do
          let(:parent) { private_group }

          it 'returns a resource not found error' do
            post_graphql_mutation(mutation, current_user: current_user)

            expect_graphql_errors_to_include(
              "The resource that you are attempting to access does not exist or you don't have " \
                'permission to perform this action'
            )
          end
        end
      end

      context 'when group_bulk_edit feature is not available' do
        before do
          stub_licensed_features(epics: true, group_bulk_edit: false)
        end

        it 'returns a resource not available message' do
          post_graphql_mutation(mutation, current_user: current_user)

          expect_graphql_errors_to_include(
            _('Group work item bulk edit is a licensed feature not available for this group.')
          )
        end
      end
    end
  end
end
