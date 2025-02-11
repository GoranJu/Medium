# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::AiGateway::Completions::SummarizeReview, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:merge_request) { create(:merge_request) }
  let_it_be(:draft_note_by_random_user) { create(:draft_note, merge_request: merge_request) }

  let(:prompt_class) { Gitlab::Llm::Templates::SummarizeReview }
  let(:options) { {} }

  let(:prompt_message) do
    build(:ai_message, :summarize_review, user: user, resource: merge_request, request_id: 'uuid')
  end

  subject(:summarize_review) { described_class.new(prompt_message, prompt_class, options).execute }

  describe '#execute' do
    context 'when there are no draft notes authored by user' do
      it 'does not make AI request' do
        expect(Gitlab::Llm::AiGateway::Client).not_to receive(:new)

        summarize_review
      end
    end

    context 'when there are draft notes authored by user' do
      let_it_be(:draft_note_by_current_user) do
        create(
          :draft_note,
          merge_request: merge_request,
          author: user,
          note: 'This is a draft note'
        )
      end

      let(:example_answer) { { "response" => "AI generated review summary" } }
      let(:example_response) { instance_double(HTTParty::Response, body: example_answer.to_json, success?: true) }

      shared_examples_for 'summarize review' do
        it 'publishes the content from the AI response' do
          expect_next_instance_of(Gitlab::Llm::AiGateway::Client) do |client|
            allow(client)
              .to receive(:complete)
              .with(
                url: "#{Gitlab::AiGateway.url}/v1/prompts/summarize_review",
                body: { 'inputs' => { draft_notes_content: draft_notes_content } }
              )
              .and_return(example_response)
          end

          expect(::Gitlab::Llm::GraphqlSubscriptionResponseService).to receive(:new).and_call_original
          expect(summarize_review[:ai_message].content).to eq(example_answer)
        end
      end

      context 'when draft note content length fits INPUT_CONTENT_LIMIT' do
        let(:draft_notes_content) { "Comment: #{draft_note_by_current_user.note}\n" }

        it_behaves_like 'summarize review'
      end

      context 'when draft note content length is longer than INPUT_CONTENT_LIMIT' do
        let(:draft_notes_content) { "" }

        before do
          stub_const("#{described_class}::INPUT_CONTENT_LIMIT", 2)
        end

        it_behaves_like 'summarize review'
      end
    end
  end
end
