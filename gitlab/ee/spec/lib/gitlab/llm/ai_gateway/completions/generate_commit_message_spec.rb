# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::GenerateCommitMessage, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :public) }
  let_it_be(:merge_request) { create(:merge_request) }

  let(:template_class) { ::Gitlab::Llm::Templates::GenerateCommitMessage }
  let(:ai_options) { {} }
  let(:ai_client) { instance_double(Gitlab::Llm::AiGateway::Client) }
  let(:ai_response) { instance_double(HTTParty::Response, body: %("Success"), success?: true) }
  let(:uuid) { SecureRandom.uuid }
  let(:prompt_message) do
    build(:ai_message, :generate_commit_message, user: user, resource: merge_request, request_id: uuid)
  end

  let(:tracking_context) { { action: :generate_commit_message, request_id: uuid } }

  subject(:generate_commit_message) { described_class.new(prompt_message, template_class, ai_options).execute }

  describe "#execute" do
    shared_examples_for 'successful completion request' do
      it 'executes a completion request and calls the response chains' do
        expect(Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          service_name: :generate_commit_message,
          tracking_context: tracking_context
        )
        expect(ai_client).to receive(:complete).with(
          url: "#{Gitlab::AiGateway.url}/v1/prompts/generate_commit_message",
          body: { 'inputs' => { diff: expected_diff } }
        ).and_return(ai_response)

        expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original

        expect(generate_commit_message[:ai_message].content).to eq("Success")
      end
    end

    let(:expected_diff) { merge_request.raw_diffs.to_a.map(&:diff).join("\n").truncate_words(10000) }

    before do
      allow(Gitlab::Llm::AiGateway::Client).to receive(:new).and_return(ai_client)
    end

    it_behaves_like 'successful completion request'

    context 'when merge request has empty raw diffs' do
      let(:expected_diff) { '' }

      before do
        allow(merge_request).to receive(:raw_diffs).and_return([])
      end

      it_behaves_like 'successful completion request'
    end

    context 'when merge request diffs is within words limit' do
      let(:expected_diff) { 'a b' }

      before do
        stub_const("#{described_class}::WORDS_LIMIT", 2)

        allow(merge_request)
          .to receive(:raw_diffs)
          .and_return([
            instance_double(
              Gitlab::Git::Diff,
              diff: 'a b'
            )
          ])
      end

      it_behaves_like 'successful completion request'
    end

    context 'when merge request diffs is more than words limit' do
      let(:expected_diff) { 'a b...' }

      before do
        stub_const("#{described_class}::WORDS_LIMIT", 2)

        allow(merge_request)
          .to receive(:raw_diffs)
          .and_return([
            instance_double(
              Gitlab::Git::Diff,
              diff: 'a b c'
            )
          ])
      end

      it_behaves_like 'successful completion request'
    end
  end
end
