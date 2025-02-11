# frozen_string_literal: true

require 'spec_helper'

RSpec.describe WorkItems::Callbacks::Iteration, feature_category: :team_planning do
  let_it_be(:user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:cadence) { create(:iterations_cadence, group: group) }
  let_it_be(:iteration) { create(:iteration, iterations_cadence: cadence) }
  let_it_be_with_reload(:work_item) { create(:work_item, project: project, author: user) }

  let(:callback) { described_class.new(issuable: work_item, current_user: user, params: params) }

  describe '#before_create' do
    subject { callback.before_create }

    it_behaves_like 'iteration change is handled'
  end

  describe '#before_update' do
    subject(:before_update_callback) { callback.before_update }

    before do
      stub_licensed_features(iterations: true)
    end

    it_behaves_like 'iteration change is handled' do
      context 'when user can admin the work item' do
        let_it_be(:other_iteration) { create(:iteration, iterations_cadence: cadence) }

        before_all do
          project.add_reporter(user)
        end

        before do
          work_item.update!(iteration: iteration)
        end

        where(:new_iteration) do
          [[lazy { other_iteration }], [nil]]
        end

        with_them do
          let(:params) { { iteration: new_iteration } }

          it 'sets a new iteration value for the work item' do
            expect { before_update_callback }.to change { work_item.iteration }.to(new_iteration).from(iteration)
          end
        end

        context 'when widget does not exist in new type' do
          let(:params) { {} }

          before do
            allow(callback).to receive(:excluded_in_new_type?).and_return(true)
            work_item.iteration = iteration
          end

          it "resets the work item's iteration" do
            expect { before_update_callback }.to change { work_item.iteration }.from(iteration).to(nil)
          end
        end
      end
    end
  end
end
