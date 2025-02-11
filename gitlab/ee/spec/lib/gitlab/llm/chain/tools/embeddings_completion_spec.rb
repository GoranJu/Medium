# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Gitlab::Llm::Chain::Tools::EmbeddingsCompletion, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }
  let_it_be(:embeddings) { build_list(:vertex_gitlab_documentation, 2) }

  let(:empty_response_message) do
    "I'm sorry, I couldn't find any documentation to answer your question. Error code: [M2000](https://docs.gitlab.com/ee/user/gitlab_duo_chat/troubleshooting.html#error-m2000)"
  end

  let(:question) { 'A question' }
  let(:answer) { 'The answer.' }
  let(:logger) { instance_double('Gitlab::Llm::Logger') }
  let(:instance) { described_class.new(current_user: user, question: question) }
  let(:ai_gateway_request) { ::Gitlab::Llm::Chain::Requests::AiGateway.new(user) }
  let(:attrs) { embeddings.pluck(:id).map { |x| "CNT-IDX-#{x}" }.join(", ") }
  let(:completion_response) { { 'response' => "#{answer} ATTRS: #{attrs}" } }
  let(:model) { ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET }

  let(:docs_search_client) { ::Gitlab::Llm::AiGateway::DocsClient.new(user) }
  let(:docs_search_args) { { query: question } }
  let(:docs_search_response) do
    {
      'response' => {
        'results' => [
          {
            'id' => 1,
            'content' => 'content',
            'metadata' => 'metadata'
          }
        ]
      }
    }
  end

  describe '#execute' do
    subject(:execute) { instance.execute }

    before do
      allow(logger).to receive(:conditional_info)
      allow(logger).to receive(:info)

      allow(::Gitlab::Llm::Logger).to receive(:build).and_return(logger)

      allow(::Gitlab::Llm::TanukiBot).to receive(:enabled_for?).and_return(true)

      allow(::Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).and_return(ai_gateway_request)
      allow(::Gitlab::Llm::AiGateway::DocsClient).to receive(:new).and_return(docs_search_client)

      allow(ai_gateway_request).to receive(:request).and_return(completion_response)
      allow(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)
    end

    it 'executes calls and returns ResponseModifier' do
      expect(ai_gateway_request).to receive(:request)
        .with({ prompt: instance_of(Array),
          options: { model: model, max_tokens: 256 } })
        .once.and_return(completion_response)
      expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)

      expect(execute).to be_an_instance_of(::Gitlab::Llm::Anthropic::ResponseModifiers::TanukiBot)
    end

    it 'yields the streamed response to the given block' do
      allow(Banzai).to receive(:render).and_return('absolute_links_content')

      expect(ai_gateway_request)
        .to receive(:request)
        .with({ prompt: instance_of(Array), options:
          { model: model, max_tokens: 256 } })
        .once
        .and_yield(answer)
        .and_return(completion_response)

      expect(docs_search_client).to receive(:search).with(**docs_search_args).and_return(docs_search_response)

      expect { |b| instance.execute(&b) }.to yield_with_args(answer)
    end

    it 'raises an error when request failed' do
      expect(logger).to receive(:error).with(a_hash_including(message: "Streaming error", error: anything))
      allow(ai_gateway_request).to receive(:request).once
                                                    .and_raise(::Gitlab::Llm::AiGateway::Client::ConnectionError.new)

      execute
    end

    context 'when user has AI features disabled' do
      before do
        allow(::Gitlab::Llm::TanukiBot).to receive(:enabled_for?).with(user: user).and_return(false)
      end

      it 'returns an empty response message' do
        expect(execute.response_body).to eq(empty_response_message)
      end
    end

    context 'when the question is not provided' do
      let(:question) { nil }

      it 'returns an empty response message' do
        expect(execute.response_body).to eq(empty_response_message)
      end
    end

    context 'when no documents are found' do
      let(:docs_search_response) { {} }

      it 'returns an empty response message' do
        expect(execute.response_body).to eq(empty_response_message)
      end
    end

    context 'when DocsClient returns nil' do
      let(:docs_search_response) { nil }

      it 'returns an empty response message' do
        expect(execute.response_body).to eq(empty_response_message)
      end
    end
  end
end
