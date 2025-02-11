# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Nav::NewDropdownHelper, feature_category: :navigation do
  describe '#new_dropdown_view_model' do
    let_it_be(:user) { build_stubbed(:user) }
    let_it_be(:group) { build_stubbed(:group) }

    let(:subject) { helper.new_dropdown_view_model(group: group, project: nil) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(helper).to receive(:can?).and_return(false)
      allow(helper).to receive(:can?).with(user, :create_epic, group).and_return(true)
    end

    shared_examples 'work item menu' do
      it 'shows create epic menu item' do
        epic_item = {
          title: 'In this group',
          menu_items: [
            ::Gitlab::Nav::TopNavMenuItem.build(
              id: 'create_epic',
              title: 'New epic',
              component: 'create_new_work_item_modal',
              data: {
                track_action: 'click_link_new_epic',
                track_label: 'plus_menu_dropdown',
                track_property: 'navigation_top'
              }
            )
          ]
        }

        expect(subject[:menu_sections][0]).to eq(epic_item)
      end
    end

    shared_examples 'legacy epic menu' do
      it 'shows create epic menu item' do
        epic_item = {
          title: 'In this group',
          menu_items: [
            ::Gitlab::Nav::TopNavMenuItem.build(
              id: 'create_epic',
              title: 'New epic',
              href: "/groups/#{group.path}/-/epics/new",
              data: {
                track_action: 'click_link_new_epic',
                track_label: 'plus_menu_dropdown',
                track_property: 'navigation_top'
              }
            )
          ]
        }

        expect(subject[:menu_sections][0]).to eq(epic_item)
      end
    end

    context 'when epics licensed feature is available' do
      before do
        stub_licensed_features(epics: true)
      end

      context 'when namespace_level_work_items flags is enabled' do
        before do
          stub_feature_flags(work_item_epics: false, namespace_level_work_items: true)
        end

        it_behaves_like 'work item menu'
      end

      context 'when work_item_epics and namespace_level_work_items flags are disabled' do
        before do
          stub_feature_flags(work_item_epics: false, namespace_level_work_items: false)
        end

        it_behaves_like 'legacy epic menu'
      end

      context 'when work_item_epics is enabled and namespace_level_work_items is disabled' do
        before do
          stub_feature_flags(work_item_epics: true, namespace_level_work_items: false)
        end

        it_behaves_like 'work item menu'
      end
    end
  end
end
