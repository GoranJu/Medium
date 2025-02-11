# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::WorkflowPolicy, feature_category: :duo_workflow do
  subject(:policy) { described_class.new(current_user, workflow) }

  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:workflow) { create(:duo_workflows_workflow, project: project) }
  let_it_be(:guest) { create(:user, guest_of: workflow.project) }
  let_it_be(:developer) { create(:user, developer_of: workflow.project) }
  let(:current_user) { guest }

  describe "read_duo_workflow and update_duo_workflow" do
    context "when duo_workflow FF is disabled" do
      before do
        stub_feature_flags(duo_workflow: false)
      end

      it { is_expected.to be_disallowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end

    context "when duo workflow is not available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(false)
      end

      it { is_expected.to be_disallowed(:read_duo_workflow) }
      it { is_expected.to be_disallowed(:update_duo_workflow) }
    end

    context "when duo workflow is available" do
      before do
        allow(::Gitlab::Llm::StageCheck).to receive(:available?).with(project, :duo_workflow).and_return(true)
      end

      context "when user is guest" do
        it { is_expected.to be_disallowed(:read_duo_workflow) }
        it { is_expected.to be_disallowed(:update_duo_workflow) }
      end

      context "when user is developer" do
        let(:current_user) { developer }

        context "when user is not workflow owner" do
          it { is_expected.to be_disallowed(:read_duo_workflow) }
          it { is_expected.to be_disallowed(:update_duo_workflow) }
        end

        context "when user is workflow owner" do
          before do
            workflow.update!(user: current_user)
          end

          it { is_expected.to be_allowed(:read_duo_workflow) }
          it { is_expected.to be_allowed(:update_duo_workflow) }

          context "when duo_features_enabled settings is turned off" do
            before do
              project.project_setting.update!(duo_features_enabled: false)
            end

            it { is_expected.to be_disallowed(:read_duo_workflow) }
            it { is_expected.to be_disallowed(:update_duo_workflow) }
          end
        end
      end
    end
  end
end
