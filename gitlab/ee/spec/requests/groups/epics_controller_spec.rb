# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Groups::EpicsController, feature_category: :portfolio_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:group) { create(:group, :private) }
  let_it_be(:epic) { create(:epic, group: group) }
  let_it_be(:user) { create(:user, developer_of: group) }

  before do
    stub_licensed_features(epics: true)
    sign_in(user)
  end

  describe 'GET #index' do
    subject(:get_index) { get group_epics_path(group) }

    before do
      stub_feature_flags(namespace_level_work_items: false)
    end

    it 'renders with feature flag enabled' do
      get_index

      expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: true)
    end

    context 'when work_item_epics disabled' do
      before do
        stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
      end

      it 'returns not found' do
        get_index

        expect(response.body).to have_pushed_frontend_feature_flags(namespaceLevelWorkItems: false)
      end
    end
  end

  describe 'GET #show' do
    context 'for work item epics' do
      context 'when feature flag is set' do
        where(:work_item_epics_list_ff, :expected_template) do
          false | 'groups/work_items/show'
          true  | 'groups/epics/work_items_index'
        end

        with_them do
          context 'when work_item_epics_list is disabled' do
            before do
              stub_feature_flags(work_item_epics_list: work_item_epics_list_ff)
            end

            it 'renders work item page' do
              get group_epic_path(group, epic)

              expect(response).to render_template(expected_template)
              expect(assigns(:work_item)).to eq(epic.work_item)
              expect(response.body).to have_pushed_frontend_feature_flags(workItemEpics: true)
            end

            it 'renders legacy page when forcing the legacy view' do
              get group_epic_path(group, epic, { force_legacy_view: true })

              expect(response).to render_template(:show)
              expect(response.body).to have_pushed_frontend_feature_flags(workItemEpics: false)
            end

            it 'renders json when requesting json response' do
              get group_epic_path(group, epic, format: :json)

              expect(response).to have_gitlab_http_status(:success)
              expect(response.media_type).to eq('application/json')
            end
          end
        end
      end

      context 'when feature flag is false' do
        before do
          stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
        end

        it 'exposes the workItemEpics flag' do
          get group_epic_path(group, epic)

          expect(response).to render_template(:show)
          expect(response.body).to have_pushed_frontend_feature_flags(workItemEpics: false)
        end

        it 'renders json when requesting json response' do
          get group_epic_path(group, epic, format: :json)

          expect(response).to have_gitlab_http_status(:success)
          expect(response.media_type).to eq('application/json')
        end
      end
    end

    context 'for summarize notes feature' do
      before do
        allow(Ability).to receive(:allowed?).and_call_original
        allow(Ability).to receive(:allowed?).with(user, :summarize_comments, epic).and_return(summarize_notes_enabled)
      end

      context 'when feature is available set' do
        let(:summarize_notes_enabled) { true }

        it 'exposes the required feature flags' do
          get group_epic_path(group, epic)

          expect(response.body).to have_pushed_frontend_feature_flags(summarizeComments: true)
        end
      end

      context 'when feature is not available' do
        let(:summarize_notes_enabled) { false }

        it 'does not expose the feature flags' do
          get group_epic_path(group, epic)

          expect(response.body).not_to have_pushed_frontend_feature_flags(summarizeComments: true)
        end
      end
    end
  end
end
