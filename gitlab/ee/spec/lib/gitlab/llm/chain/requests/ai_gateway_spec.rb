# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::Chain::Requests::AiGateway, feature_category: :duo_chat do
  let_it_be(:user) { build(:user) }
  let(:tracking_context) { { action: 'chat', request_id: 'uuid' } }

  subject(:instance) { described_class.new(user, tracking_context: tracking_context) }

  describe 'initializer' do
    it 'initializes the AI Gateway client' do
      expect(instance.ai_client.class).to eq(::Gitlab::Llm::AiGateway::Client)
    end

    context 'when alternative service name is passed' do
      it 'creates ai gateway client with different service name' do
        expect(::Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          service_name: :alternative,
          tracking_context: tracking_context
        )

        described_class.new(user, service_name: :alternative, tracking_context: tracking_context)
      end
    end

    context 'when duo chat is self-hosted' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :self_hosted) }

      it 'creates ai gateway client with self-hosted-models service name' do
        expect(::Gitlab::Llm::AiGateway::Client).to receive(:new).with(
          user,
          service_name: :self_hosted_models,
          tracking_context: tracking_context
        )

        described_class.new(user, service_name: :duo_chat, tracking_context: tracking_context)
      end
    end
  end

  describe '#request' do
    let(:logger) { instance_double(Gitlab::Llm::Logger) }
    let(:ai_client) { double }
    let(:endpoint) { described_class::ENDPOINT }
    let(:url) { "#{::Gitlab::AiGateway.url}#{endpoint}" }
    let(:model) { nil }
    let(:expected_model) { described_class::CLAUDE_3_5_SONNET }
    let(:provider) { :anthropic }
    let(:params) do
      {
        max_tokens_to_sample: described_class::DEFAULT_MAX_TOKENS,
        stop_sequences: ["\n\nHuman", "Observation:"],
        temperature: 0.1
      }
    end

    let(:user_prompt) { "some user request" }
    let(:options) { { model: model } }
    let(:prompt) { { prompt: user_prompt, options: options } }
    let(:payload) do
      {
        content: user_prompt,
        provider: provider,
        model: expected_model,
        params: params
      }
    end

    let(:body) do
      {
        prompt_components: [{
          type: described_class::DEFAULT_TYPE,
          metadata: {
            source: described_class::DEFAULT_SOURCE,
            version: Gitlab.version_info.to_s
          },
          payload: payload
        }],
        stream: true
      }
    end

    let(:response) { 'Hello World' }

    subject(:request) { instance.request(prompt) }

    before do
      allow(Gitlab::Llm::Logger).to receive(:build).and_return(logger)
      allow(logger).to receive(:conditional_info)
      allow(instance).to receive(:ai_client).and_return(ai_client)
    end

    shared_examples 'performing request to the AI Gateway' do
      it 'returns the response from AI Gateway' do
        expect(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)

        expect(request).to eq(response)
      end
    end

    it 'logs the request and response' do
      expect(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
      expect(logger).to receive(:conditional_info).with(
        user,
        a_hash_including(
          message: "Made request to AI Client",
          klass: described_class.to_s,
          prompt: user_prompt,
          response_from_llm: response
        ))

      request
    end

    it 'calls the AI Gateway streaming endpoint and yields response without stripping it' do
      expect(ai_client).to receive(:stream).with(url: url, body: body).and_yield(response)
        .and_return(response)

      expect { |b| instance.request(prompt, &b) }.to yield_with_args(response)
    end

    it_behaves_like 'performing request to the AI Gateway'

    it_behaves_like 'tracks events for AI requests', 4, 2, klass: 'Gitlab::Llm::Anthropic::Client' do
      before do
        allow(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
      end
    end

    context 'when additional params are passed in as options' do
      let(:options) do
        { temperature: 1, stop_sequences: %W[\n\Foo Bar:], max_tokens_to_sample: 1024, disallowed_param: 1, topP: 1 }
      end

      let(:params) do
        {
          max_tokens_to_sample: 1024,
          stop_sequences: ["\n\Foo", "Bar:"],
          temperature: 1
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when unit primitive is passed with no corresponding feature setting' do
      let(:endpoint) { "#{described_class::BASE_ENDPOINT}/test" }

      subject(:request) { instance.request(prompt, unit_primitive: :test) }

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when other model is passed' do
      let(:model) { ::Gitlab::Llm::Concerns::AvailableModels::VERTEX_MODEL_CHAT }
      let(:expected_model) { model }
      let(:provider) { :vertex }
      let(:params) { { temperature: 0.1 } } # This checks that non-vertex params lie `stop_sequence` are filtered out

      it_behaves_like 'performing request to the AI Gateway'
      it_behaves_like 'tracks events for AI requests', 4, 2, klass: 'Gitlab::Llm::VertexAi::Client' do
        before do
          allow(ai_client).to receive(:stream).with(url: url, body: body).and_return(response)
        end
      end
    end

    context "when using the claude haiku model" do
      let(:model) { ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_HAIKU }
      let(:expected_model) { ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_HAIKU }
      let(:expected_response) { "Hello World" }

      it "calls ai gateway client with 3.5 haiku model" do
        expect(ai_client).to receive(:stream).with(
          hash_including(
            body: hash_including(
              prompt_components: array_including(
                hash_including(
                  payload: hash_including(
                    model: expected_model
                  )
                )
              )
            )
          )
        ).and_return(response)

        request

        expect(response).to eq(expected_response)
      end
    end

    context "when claude 3.5 feature flag is disabled" do
      let(:model) { ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_HAIKU }
      let(:expected_response) { "Hello World" }

      before do
        stub_feature_flags(claude_3_5_haiku_rollout: false)
      end

      it "calls ai gateway client with original model" do
        expect(ai_client).to receive(:stream).with(
          hash_including(
            body: hash_including(
              prompt_components: array_including(
                hash_including(
                  payload: hash_including(model: model)
                )
              )
            )
          )
        ).and_return(response)

        request

        expect(response).to eq(expected_response)
      end
    end

    context 'when invalid model is passed' do
      let(:model) { 'test' }

      it 'returns nothing' do
        expect(ai_client).not_to receive(:stream).with(url: url, body: anything)

        expect(request).to eq(nil)
      end
    end

    context "when no model is provided" do
      let(:model) { nil }
      let(:expected_model) { ::Gitlab::Llm::Concerns::AvailableModels::CLAUDE_3_5_SONNET }
      let(:expected_response) { "Hello World" }

      it "calls ai gateway client with claude 3.5 sonnet model defaulted" do
        expect(ai_client).to receive(:stream).with(
          hash_including(
            body: hash_including(
              prompt_components: array_including(
                hash_including(
                  payload: hash_including(model: expected_model)
                )
              )
            )
          )
        )

        request

        expect(response).to eq(expected_response)
      end
    end

    context 'when user is using a Self-hosted model' do
      let!(:ai_feature) { create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat) }
      let!(:self_hosted_model) { create(:ai_self_hosted_model, api_token: 'test_token') }
      let(:expected_model) { self_hosted_model.model.to_s }

      let(:payload) do
        {
          content: user_prompt,
          provider: :litellm,
          model: expected_model,
          model_endpoint: self_hosted_model.endpoint,
          model_api_key: self_hosted_model.api_token,
          model_identifier: "provider/some-model",
          params: params
        }
      end

      it_behaves_like 'performing request to the AI Gateway'
    end

    context 'when request is sent to chat tools implemented via agents' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, feature: :duo_chat, provider: :self_hosted) }

      let(:options) do
        {
          use_ai_gateway_agent_prompt: true,
          inputs: inputs
        }
      end

      let(:body) do
        {
          stream: true,
          inputs: inputs,
          model_metadata: model_metadata
        }
      end

      let(:prompt) { { prompt: user_prompt, options: options } }
      let(:inputs) { { field: :test_field } }

      let(:model_metadata) do
        { api_key: "token", endpoint: "http://localhost:11434/v1", name: "mistral", provider: :openai, identifier: 'provider/some-model' }
      end

      context 'with no unit primitive corresponding a feature setting' do
        let(:unit_primitive) { :test }
        let(:endpoint) { "#{described_class::BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}" }

        subject(:request) { instance.request(prompt, unit_primitive: unit_primitive) }

        it_behaves_like 'performing request to the AI Gateway'
      end

      context 'with a unit primitive corresponding a feature setting' do
        let_it_be(:model_api_key) { 'explain_code_token_model' }
        let_it_be(:model_identifier) { 'provider/some-cool-model' }
        let_it_be(:model_endpoint) { 'http://example.explain_code.dev' }
        let_it_be(:self_hosted_model) do
          create(:ai_self_hosted_model, name: 'explain_code', endpoint: model_endpoint, api_token: model_api_key,
            identifier: model_identifier)
        end

        let_it_be(:sub_feature_setting) do
          create(
            :ai_feature_setting,
            feature: :duo_chat_explain_code,
            provider: :self_hosted,
            self_hosted_model: self_hosted_model
          )
        end

        let(:unit_primitive) { :explain_code }

        let(:endpoint) { "#{described_class::BASE_PROMPTS_CHAT_ENDPOINT}/#{unit_primitive}" }

        subject(:request) { instance.request(prompt, unit_primitive: unit_primitive) }

        context 'when ai_duo_chat_sub_features_settings feature is disabled' do
          before do
            stub_feature_flags(ai_duo_chat_sub_features_settings: false)
          end

          # it fallsback to the chat feature settings
          it_behaves_like 'performing request to the AI Gateway'
        end

        context 'when ai_duo_chat_sub_features_settings feature is enabled' do
          let(:model_metadata) do
            { api_key: model_api_key, endpoint: model_endpoint, name: "mistral", provider: :openai,
              identifier: model_identifier }
          end

          it_behaves_like 'performing request to the AI Gateway'
        end
      end
    end
  end
end
