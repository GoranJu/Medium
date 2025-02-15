# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ai::DuoWorkflows::WorkflowCheckpointEventPresenter, feature_category: :duo_workflow do
  let(:checkpoint) { build_stubbed(:duo_workflows_checkpoint) }
  let_it_be(:user) { build_stubbed(:user) }

  subject(:presenter) { described_class.new(checkpoint, current_user: user) }

  describe 'timestamp' do
    it 'returns the checkpoint thread_ts' do
      expect(presenter.timestamp).to eq(Time.parse(checkpoint.thread_ts))
    end
  end

  describe 'parent_timestamp' do
    it 'returns nil if the checkpoint has no parent ts' do
      checkpoint.parent_ts = nil
      expect(presenter.parent_timestamp).to be_nil
    end

    it 'returns the checkpoint parent_ts' do
      expect(presenter.parent_timestamp).to eq(Time.parse(checkpoint.parent_ts))
    end
  end

  describe 'metadata' do
    it 'returns the checkpoint metadata' do
      expect(presenter.metadata).to eq(checkpoint.metadata)
    end
  end

  describe 'checkpoint' do
    it 'returns the checkpoint' do
      expect(presenter.checkpoint).to eq(checkpoint.checkpoint)
    end
  end

  describe 'workflow_status' do
    it 'returns the workflow status' do
      expect(presenter.workflow_status).to eq(checkpoint.workflow.status)
    end
  end

  describe 'workflow_goal' do
    it 'returns the workflow goal' do
      expect(presenter.workflow_goal).to eq(checkpoint.workflow.goal)
    end
  end

  describe 'workflow_definition' do
    it 'returns the workflow definition' do
      expect(presenter.workflow_definition).to eq(checkpoint.workflow.workflow_definition)
    end
  end
end
