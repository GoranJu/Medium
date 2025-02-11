# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'groups/settings/_advanced.html.haml', feature_category: :groups_and_projects do
  let_it_be(:user) { build_stubbed(:user) }

  let(:group) { build_stubbed(:group) }

  before do
    group.add_owner(user)

    assign(:group, group)
    allow(view).to receive(:current_user) { user }
  end

  context 'when restoring a group' do
    shared_examples_for 'renders restore group settings' do
      it 'renders restore group card and action' do
        render

        expect(rendered).to render_template('shared/groups_projects/settings/_restore')
        expect(rendered).to have_link('Restore group')
      end
    end

    shared_examples_for 'does not render restore group settings' do
      it 'does not render restore group card and action' do
        render

        expect(rendered).to render_template('shared/groups_projects/settings/_restore')
        expect(rendered).not_to have_link('Restore group')
      end
    end

    context 'when adjourned_deletion_for_projects_and_groups is enabled' do
      before do
        allow(group).to receive(:licensed_feature_available?).and_return(false)
        allow(group).to receive(:licensed_feature_available?)
          .with(:adjourned_deletion_for_projects_and_groups).and_return(true)
      end

      context 'when group is pending deletion' do
        before do
          allow(group).to receive_messages(
            marked_for_deletion?: true,
            marked_for_deletion_on: 1.day.ago
          )
        end

        it_behaves_like 'renders restore group settings'
      end

      context 'when group is not pending deletion' do
        it_behaves_like 'does not render restore group settings'
      end
    end

    context 'when adjourned_deletion_for_projects_and_groups is disabled' do
      before do
        allow(group).to receive(:licensed_feature_available?).and_return(false)
        allow(group).to receive(:licensed_feature_available?)
          .with(:adjourned_deletion_for_projects_and_groups).and_return(false)
      end

      it_behaves_like 'does not render restore group settings'
    end
  end
end
