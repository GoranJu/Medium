# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Group Level Work Items', feature_category: :team_planning do
  let_it_be(:group) { create(:group, :private) }
  let_it_be(:current_user) { create(:user, developer_of: group) }
  let_it_be(:work_item) { create(:work_item, :group_level, namespace: group) }

  describe 'GET /groups/:group/-/work_items/:iid' do
    let(:iid) { work_item.iid }

    subject(:show) { get group_work_item_path(group, iid) }

    before do
      sign_in(current_user)
      stub_licensed_features(epics: true)
      stub_feature_flags(namespace_level_work_items: true)
    end

    it 'renders show' do
      show

      expect(response).to have_gitlab_http_status(:ok)
      expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: true)
    end

    context 'when the new page gets requested' do
      context 'when work item type is epic' do
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

        it 'redirects to /epic/:iid' do
          show

          expect(response).to redirect_to(group_epic_path(group, work_item.iid))
        end
      end

      context 'when the new page gets requested' do
        let(:iid) { 'new' }

        it 'renders show' do
          show

          expect(response).to have_gitlab_http_status(:ok)
          expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: true)
          expect(response).to render_template(:show)
        end
      end
    end

    context 'when namespace_level_work_items is disabled' do
      before do
        stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
      end

      let(:iid) { 'new' }

      it 'returns not found' do
        show

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when work_item_epics disabled' do
      before do
        stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
      end

      context 'when work item type is epic' do
        let_it_be(:work_item) { create(:work_item, :epic, namespace: group) }

        it 'redirects to /epic/:iid' do
          show

          expect(response).to redirect_to(group_epic_path(group, work_item.iid))
        end
      end

      context 'when work item does not exist' do
        let(:iid) { non_existing_record_id }

        it 'renders not found' do
          show

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when work item type is not epic' do
        let_it_be(:work_item) { create(:work_item, :issue, namespace: group) }

        it 'returns not found' do
          show

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end
    end
  end
end
