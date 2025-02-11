# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::DuoWorkflows::Workflow, feature_category: :duo_workflow do
  let(:user) { create(:user) }
  let(:another_user) { create(:user) }
  let(:owned_workflow) { create(:duo_workflows_workflow, user: user) }
  let(:not_owned_workflow) { create(:duo_workflows_workflow, user: another_user) }

  describe 'associations' do
    it { is_expected.to have_many(:checkpoints).class_name('Ai::DuoWorkflows::Checkpoint') }
    it { is_expected.to have_many(:checkpoint_writes).class_name('Ai::DuoWorkflows::CheckpointWrite') }
  end

  describe '.for_user_with_id!' do
    it 'finds the workflow for the given user and id' do
      expect(described_class.for_user_with_id!(user.id, owned_workflow.id)).to eq(owned_workflow)
    end

    it 'raises an error if the workflow is for a different user' do
      expect { described_class.for_user_with_id!(another_user, owned_workflow.id) }
        .to raise_error(ActiveRecord::RecordNotFound)
    end
  end

  describe '.for_user' do
    it 'finds the workflows for the given user' do
      expect(described_class.for_user(user)).to eq([owned_workflow])
    end
  end

  describe '.for_project' do
    let_it_be(:project) { create(:project) }
    let(:project_workflow) { create(:duo_workflows_workflow, project: project) }

    it 'finds the workflows for the given project' do
      expect(described_class.for_project(project)).to eq([project_workflow])
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_length_of(:goal).is_at_most(4096) }

    describe '#only_known_agent_priviliges' do
      it 'is valid with a valid privilege' do
        workflow = described_class.new(agent_privileges: [
          Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES
        ])
        expect(workflow).to be_valid
      end

      it 'is invalid with an invalid privilege' do
        workflow = described_class.new(agent_privileges: [999])
        expect(workflow).not_to be_valid
        expect(workflow.errors[:agent_privileges]).to include("contains an invalid value 999")
      end
    end
  end

  describe '#agent_privileges' do
    it 'returns the privileges that are set' do
      workflow = described_class.new(agent_privileges: [
        Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_FILES,
        Ai::DuoWorkflows::Workflow::AgentPrivileges::READ_WRITE_GITLAB
      ])

      # Validation triggers setting the default
      expect(workflow).to be_valid

      expect(workflow.agent_privileges).to match_array([
        described_class::AgentPrivileges::READ_WRITE_FILES,
        described_class::AgentPrivileges::READ_WRITE_GITLAB
      ])
    end

    it 'replaces with DEFAULT_PRIVILEGES when set to nil' do
      workflow = described_class.new(agent_privileges: nil)

      # Validation triggers setting the default
      expect(workflow).to be_valid

      expect(workflow.agent_privileges).to match_array([
        described_class::AgentPrivileges::READ_WRITE_FILES,
        described_class::AgentPrivileges::READ_ONLY_GITLAB
      ])
    end

    it 'replaces with DEFAULT_PRIVILEGES when not set' do
      workflow = described_class.new

      # Validation triggers setting the default
      expect(workflow).to be_valid

      expect(workflow.agent_privileges).to match_array([
        described_class::AgentPrivileges::READ_WRITE_FILES,
        described_class::AgentPrivileges::READ_ONLY_GITLAB
      ])
    end
  end

  describe 'state transitions' do
    using RSpec::Parameterized::TableSyntax
    where(:status, :can_start, :can_pause, :can_resume, :can_finish, :can_drop, :can_stop, :can_retry,
      :can_require_input) do
      0 | true  | false | false | false | true  | true  | false | false
      1 | false | true  | false | true  | true  | true  | true  | true
      2 | false | false | true  | false | true  | true  | false | false
      3 | false | false | false | false | false | false | false | false
      4 | false | false | false | false | false | false | true  | false
      5 | false | false | false | false | false | false | true  | false
      6 | false | false | true  | false | true  | true  | false | false
    end

    with_them do
      it 'adheres to state machine rules', :aggregate_failures do
        owned_workflow.status = status

        expect(owned_workflow.can_start?).to eq(can_start)
        expect(owned_workflow.can_pause?).to eq(can_pause)
        expect(owned_workflow.can_resume?).to eq(can_resume)
        expect(owned_workflow.can_finish?).to eq(can_finish)
        expect(owned_workflow.can_drop?).to eq(can_drop)
      end
    end
  end
end
