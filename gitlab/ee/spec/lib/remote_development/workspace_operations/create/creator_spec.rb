# frozen_string_literal: true

require 'spec_helper'

Messages = RemoteDevelopment::Messages

RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::Creator, feature_category: :workspaces do
  let(:rop_steps) do
    [
      [RemoteDevelopment::WorkspaceOperations::Create::PersonalAccessTokenCreator, :and_then],
      [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceCreator, :and_then],
      [RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator, :and_then]
    ]
  end

  let_it_be(:user) { create(:user) }
  let_it_be(:agent) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
  let(:random_string) { 'abcdef' }

  let(:params) do
    {
      agent: agent
    }
  end

  let(:initial_value) do
    {
      params: params,
      user: user
    }
  end

  let(:workspace) { instance_double("RemoteDevelopment::Workspace") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper

  let(:updated_value) do
    namespace_prefix = RemoteDevelopment::WorkspaceOperations::Create::CreateConstants::NAMESPACE_PREFIX
    initial_value.merge(
      {
        workspace_name: "workspace-#{agent.id}-#{user.id}-#{random_string}",
        workspace_namespace: "#{namespace_prefix}-#{agent.id}-#{user.id}-#{random_string}"
      }
    )
  end

  before do
    allow(SecureRandom).to receive(:alphanumeric) { random_string }
  end

  describe "happy path" do
    let(:expected_response) do
      Gitlab::Fp::Result.ok(RemoteDevelopment::Messages::WorkspaceCreateSuccessful.new(updated_value))
    end

    it "returns expected response" do
      # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
      expect do
        described_class.create(initial_value) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord call
      end
        .to invoke_rop_steps(rop_steps)
              .from_main_class(described_class)
              .with_context_passed_along_steps(updated_value)
              .and_return_expected_value(expected_response)
    end
  end

  describe "error cases" do
    let(:error_details) { "some error details" }
    let(:err_message_content) { { errors: error_details } }

    shared_examples "rop invocation with error response" do
      it "returns expected response" do
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect do
          described_class.create(initial_value) # rubocop:disable Rails/SaveBang -- this is not an ActiveRecord call
        end
          .to invoke_rop_steps(rop_steps)
                .from_main_class(described_class)
                .with_context_passed_along_steps(updated_value)
                .with_err_result_for_step(err_result_for_step)
                .and_return_expected_value(expected_response)
      end
    end

    # rubocop:disable Style/TrailingCommaInArrayLiteral -- let the last element have a comma for simpler diffs
    where(:case_name, :err_result_for_step, :expected_response) do
      [
        [
          "when PersonalAccessTokenCreator returns PersonalAccessTokenModelCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::PersonalAccessTokenCreator,
            returned_message: lazy { Messages::PersonalAccessTokenModelCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceCreator returns WorkspaceModelCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::WorkspaceCreator,
            returned_message: lazy { Messages::WorkspaceModelCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
        [
          "when WorkspaceVariablesCreator returns WorkspaceVariablesModelCreateFailed",
          {
            step_class: RemoteDevelopment::WorkspaceOperations::Create::WorkspaceVariablesCreator,
            returned_message: lazy { Messages::WorkspaceVariablesModelCreateFailed.new(err_message_content) }
          },
          lazy { Gitlab::Fp::Result.err(Messages::WorkspaceCreateFailed.new(err_message_content)) }
        ],
      ]
    end
    # rubocop:enable Style/TrailingCommaInArrayLiteral
    with_them do
      it_behaves_like "rop invocation with error response"
    end
  end
end
