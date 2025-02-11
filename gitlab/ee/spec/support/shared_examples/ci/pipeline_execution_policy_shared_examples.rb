# frozen_string_literal: true

RSpec.shared_context 'with pipeline policy context' do
  let(:pipeline_policy_context) do
    Gitlab::Ci::Pipeline::ExecutionPolicies::PipelineContext.new(project: project, command: command)
  end

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(project: project)
  end

  let_it_be(:project) { create(:project, :repository) }
  let(:creating_policy_pipeline) { false }
  let(:current_policy) { FactoryBot.build(:pipeline_execution_policy_pipeline) }
  let(:execution_policy_pipelines) { [] }

  before do
    allow(pipeline_policy_context.pipeline_execution_context).to receive_messages(
      creating_policy_pipeline?: creating_policy_pipeline,
      policy_pipelines: execution_policy_pipelines,
      current_policy: creating_policy_pipeline ? current_policy : nil
    )
  end
end
