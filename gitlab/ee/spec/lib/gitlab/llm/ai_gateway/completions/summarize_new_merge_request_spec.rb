# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::SummarizeNewMergeRequest, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :repository) }
  let(:prompt_class) { Gitlab::Llm::Templates::SummarizeNewMergeRequest }
  let(:prompt_message) do
    build(:ai_message, :summarize_new_merge_request, user: user, resource: project, request_id: 'uuid')
  end

  let(:example_answer) { { "response" => "AI generated merge request summary" } }
  let(:example_response) { instance_double(HTTParty::Response, body: example_answer.to_json, success?: true) }

  subject(:summarize_new_merge_request) { described_class.new(prompt_message, prompt_class, options).execute }

  describe '#execute' do
    shared_examples 'makes AI request and publishes response' do
      it 'makes AI request and publishes response' do
        extracted_diff = Gitlab::Llm::Utils::MergeRequestTool.extract_diff(
          source_project: options[:source_project] || project,
          source_branch: options[:source_branch],
          target_project: project,
          target_branch: options[:target_branch],
          character_limit: described_class::CHARACTER_LIMIT
        )

        expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
          expect(client)
            .to receive(:complete)
            .with(
              url: "#{Gitlab::AiGateway.url}/v1/prompts/summarize_new_merge_request",
              body: { 'inputs' => { extracted_diff: extracted_diff } }
            )
            .and_return(example_response)
        end

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original
        expect(summarize_new_merge_request[:ai_message].content).to eq(example_answer)
      end
    end

    context 'with valid source branch and project' do
      let(:options) do
        {
          source_branch: 'feature',
          target_branch: project.default_branch,
          source_project: project
        }
      end

      it_behaves_like 'makes AI request and publishes response'
    end

    context 'when extracted diff is blank' do
      let(:options) do
        {
          source_branch: 'does-not-exist',
          target_branch: project.default_branch,
          source_project: project
        }
      end

      it 'does not make an AI request and returns nil' do
        expect(Gitlab::Llm::AiGateway::Client).not_to receive(:new)
        expect(summarize_new_merge_request).to be_nil
      end
    end

    context 'when source_project_id is invalid' do
      let(:options) do
        {
          source_branch: 'feature',
          target_branch: project.default_branch,
          source_project_id: non_existing_record_id
        }
      end

      it_behaves_like 'makes AI request and publishes response'
    end
  end
end
