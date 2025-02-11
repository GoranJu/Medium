# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CodeSuggestions::Tasks::CodeGeneration, feature_category: :code_suggestions do
  let_it_be(:current_user) { create(:user) }

  let(:content_above_cursor) { 'some content_above_cursor' }
  let(:content_below_cursor) { 'some content_below_cursor' }
  let(:instruction) { CodeSuggestions::Instruction.from_trigger_type('comment') }
  let(:current_file) do
    {
      'file_name' => 'test.py',
      'content_above_cursor' => content_above_cursor,
      'content_below_cursor' => content_below_cursor
    }.with_indifferent_access
  end

  let(:expected_current_file) do
    { current_file: { file_name: 'test.py', content_above_cursor: 'sor', content_below_cursor: 'som' } }
  end

  let(:client) { nil }

  subject(:task) do
    described_class.new(
      params: params,
      unsafe_passthrough_params: unsafe_params,
      client: client,
      current_user: current_user
    )
  end

  context 'when using saas anthropic model' do
    before do
      allow(CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages)
        .to receive(:new).and_return(anthropic_messages_prompt)
      stub_const('CodeSuggestions::Tasks::Base::AI_GATEWAY_CONTENT_SIZE', 3)
    end

    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [{ 'model_engine' => 'anthropic' }]
      }.with_indifferent_access
    end

    let(:params) do
      {
        code_generation_model_family: :anthropic,
        content_above_cursor: content_above_cursor,
        instruction: instruction,
        current_file: current_file,
        model_name: 'claude-3-5-sonnet-20240620'
      }
    end

    let(:anthropic_request_params) do
      {
        'prompt_components' => [
          {
            'type' => 'code_editor_generation',
            'payload' => {
              'file_name' => 'test.py',
              'content_above_cursor' => 'some content_above_cursor',
              'content_below_cursor' => 'some content_below_cursor',
              'language_identifier' => 'Python',
              'prompt_id' => 'code_suggestions/generations',
              'prompt_version' => '^1.0.0',
              'prompt_enhancer' => {
                'examples_array' => [
                  {
                    'example' => 'class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ',
                    'response' => "return self.visibility == 'PUBLIC'",
                    'trigger_type' => 'comment'
                  },
                  {
                    'example' => "# get the current user's name from the session data\\n{{cursor}}",
                    'response' => "username = session['username']\\nreturn username",
                    'trigger_type' => 'comment'
                  }
                ],
                'trimmed_content_above_cursor' => 'some content_above_cursor',
                'trimmed_content_below_cursor' => 'some content_below_cursor',
                'related_files' => '',
                'related_snippets' => '',
                'libraries' => '',
                'user_instruction' => 'Generate the best possible code based on instructions.'
              }
            }
          }
        ]
      }
    end

    let(:anthropic_messages_prompt) do
      instance_double(
        CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages,
        request_params: anthropic_request_params
      )
    end

    let(:expected_body) do
      {
        'current_file' => {
          'content_above_cursor' => 'sor',
          'content_below_cursor' => 'som',
          'file_name' => 'test.py'
        },
        'prompt_components' => [
          {
            'payload' => {
              'content_above_cursor' => 'some content_above_cursor',
              'content_below_cursor' => 'some content_below_cursor',
              'file_name' => 'test.py',
              'language_identifier' => 'Python',
              'prompt_enhancer' => {
                'examples_array' => [
                  {
                    'example' => 'class Project:\\n  def __init__(self, name, public):{{cursor}}\\n\\n ',
                    'response' => "return self.visibility == 'PUBLIC'",
                    'trigger_type' => 'comment'
                  },
                  {
                    'example' => "# get the current user's name from the session data\\n{{cursor}}",
                    'response' => "username = session['username']\\nreturn username",
                    'trigger_type' => 'comment'
                  }
                ],
                'trimmed_content_above_cursor' => 'some content_above_cursor',
                'trimmed_content_below_cursor' => 'some content_below_cursor',
                'related_files' => '',
                'related_snippets' => '',
                'libraries' => '',
                'user_instruction' => 'Generate the best possible code based on instructions.'
              },
              'prompt_id' => 'code_suggestions/generations',
              'prompt_version' => '^1.0.0'
            },
            'type' => 'code_editor_generation'
          }
        ],
        'telemetry' => [{ 'model_engine' => 'anthropic' }]
      }
    end

    let(:expected_feature_name) { :code_suggestions }

    it 'calls code creation Anthropic' do
      task.body
      expect(CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages)
        .to have_received(:new).with(params, current_user)
    end

    it_behaves_like 'code suggestion task' do
      let(:endpoint_path) { 'v3/code/completions' }
    end

    context 'when a client is provided' do
      let(:client) { CodeSuggestions::Client.new(headers) }

      context 'when the client supports SSE streaming' do
        let(:headers) { { 'X-Supports-Sse-Streaming' => 'true' } }

        it_behaves_like 'code suggestion task' do
          let(:endpoint_path) { 'v4/code/suggestions' }
        end
      end

      context 'when the client does not support SSE streaming' do
        let(:headers) { {} }

        it_behaves_like 'code suggestion task' do
          let(:endpoint_path) { 'v3/code/completions' }
        end
      end
    end
  end

  context 'when using self hosted model' do
    let(:unsafe_params) do
      {
        'current_file' => current_file,
        'telemetry' => [],
        'stream' => false
      }.with_indifferent_access
    end

    let(:params) do
      {
        current_file: current_file,
        generation_type: 'empty_function'
      }
    end

    context 'on setting the provider as `self_hosted`' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :self_hosted) }

      it_behaves_like 'code suggestion task' do
        let(:endpoint_path) { 'v2/code/generations' }
        let(:expected_body) do
          {
            "telemetry" => [],
            "prompt_id" => "code_suggestions/generations",
            "current_file" => {
              "content_above_cursor" => "some content_above_cursor",
              "content_below_cursor" => "some content_below_cursor",
              "file_name" => "test.py"
            },
            "model_api_key" => "token",
            "model_endpoint" => "http://localhost:11434/v1",
            "model_identifier" => "provider/some-model",
            "model_name" => "mistral",
            "model_provider" => "litellm",
            "prompt" => "",
            "prompt_version" => 2,
            "stream" => false
          }
        end

        let(:expected_feature_name) { :self_hosted_models }
      end
    end

    context 'on setting the provider as `disabled`' do
      let_it_be(:feature_setting) { create(:ai_feature_setting, provider: :disabled) }

      it 'is a disabled task' do
        expect(task.feature_disabled?).to eq(true)
      end
    end
  end
end
