# frozen_string_literal: true

# AIGW v3 api for code generation receives params
RSpec.shared_examples 'code generation AI Gateway request params' do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:project) { create(:project) }

  let(:file_name) { 'main.go' }
  let(:content_above_cursor) { "package main\n\nimport \"fmt\"\n\nfunc main() {\n" }
  let(:content_below_cursor) { "func test() {\n" }
  let(:comment) { 'My comment instructions' }
  let(:instruction) { instance_double(CodeSuggestions::Instruction, instruction: comment, trigger_type: 'comment') }
  let(:examples) { [{ example: 'func hello() {', response: 'func hello() {<new_code>fmt.Println("hello")' }] }
  let(:stream) { true }

  let(:context) do
    [
      { type: 'file', name: 'main.go', content:
        <<~CONTENT
          package main

          func main()
            fullName("John", "Doe")
          }
        CONTENT
      },
      { type: 'snippet', name: 'fullName', content:
        <<~CONTENT
          func fullName(first, last string) {
            fmt.Println(first, last)
          }
        CONTENT
      }
    ]
  end

  let(:current_file_params) do
    {
      file_name: file_name,
      content_above_cursor: content_above_cursor,
      content_below_cursor: content_below_cursor
    }
  end

  let(:params) do
    {
      current_user: current_user,
      project: project,
      instruction: instruction,
      current_file: current_file_params,
      context: context,
      stream: stream
    }
  end

  subject { described_class.new(params, current_user) }

  # rubocop:disable RSpec/MultipleMemoizedHelpers -- We need extra helpers to define tables
  describe '#request_params' do
    context 'when all parameters are present' do
      before_all do
        create(:xray_report, lang: 'go', project: project,
          payload: { libs: [{ name: 'zlib (1.2.3)' }, { name: 'boost (2.0.0)' }, { name: 'jwt (3.1.2)' }] })
      end

      let(:expected_file_name) { file_name }
      let(:expected_content_above_cursor) { content_above_cursor }
      let(:expected_content_below_cursor) { content_below_cursor }
      let(:expected_language_identifier) { 'Go' }
      let(:expected_examples_array) { examples }
      let(:expected_trimmed_content_above_cursor) { content_above_cursor }
      let(:expected_trimmed_content_below_cursor) { content_below_cursor }
      let(:expected_libraries) { ['zlib (1.2.3)', 'boost (2.0.0)', 'jwt (3.1.2)'] }
      let(:expected_user_instruction) { comment }
      let(:expected_stream) { true }
      let(:expected_prompt_id) { "code_suggestions/generations" }
      let(:expected_prompt_version) { "2.0.0" }

      let(:expected_related_files) do
        [
          "<file_content file_name=\"main.go\">\npackage main\n\nfunc main()\n  " \
            "fullName(\"John\", \"Doe\")\n}\n\n</file_content>\n"
        ]
      end

      let(:expected_related_snippets) do
        [
          "<snippet_content name=\"fullName\">\nfunc fullName(first, last string) {\n  " \
            "fmt.Println(first, last)\n}\n\n</snippet_content>\n"
        ]
      end

      before do
        allow_next_instance_of(CodeSuggestions::ProgrammingLanguage) do |instance|
          allow(instance).to receive(:generation_examples).with(type: instruction.trigger_type).and_return(examples)
        end
      end

      it 'returns expected request params' do
        expect(subject.request_params).to eq(expected_request_params)
      end

      it 'tracks an X-Ray event' do
        expect(Gitlab::InternalEvents).to receive(:track_event).with(
          'include_repository_xray_data_into_code_generation_prompt',
          project: project,
          namespace: project.namespace,
          user: current_user
        )

        subject.request_params
      end

      context 'when the content_above_cursor length exceeds the prompt limit' do
        let(:limit) { 10 }
        let(:expected_trimmed_content_above_cursor) { content_above_cursor.last(limit) }
        let(:expected_trimmed_content_below_cursor) { '' }

        before do
          stub_const('CodeSuggestions::Prompts::CodeGeneration::AiGatewayMessages::MAX_INPUT_CHARS', limit)
        end

        it 'returns expected request params' do
          expect(subject.request_params).to eq(expected_request_params)
        end

        context 'when the combined content_above_cursor and content_below_cursor length exceeds the prompt limit' do
          let(:limit) { content_above_cursor.size + 5 }
          let(:expected_trimmed_content_above_cursor) { content_above_cursor }
          let(:expected_trimmed_content_below_cursor) { content_below_cursor.first(5) }

          it 'returns expected request params' do
            expect(subject.request_params).to eq(expected_request_params)
          end
        end
      end

      context 'when using claude_3_5_sonnet_20241022_for_code_gen' do
        let(:expected_saas) { true }
        let(:expected_prompt_id) { "code_suggestions/generations" }
        let(:expected_prompt_version) { "1.0.1-dev" }

        before do
          stub_feature_flags(incident_fail_over_generation_provider: false)
          stub_feature_flags(claude_3_5_sonnet_20241022_for_code_gen: true)
        end

        it 'returns expected request params' do
          expect(subject.request_params).to eq(expected_request_params)
        end
      end

      context 'when using claude_3_5_sonnet_20240620_for_code_gen' do
        let(:expected_saas) { true }
        let(:expected_prompt_id) { "code_suggestions/generations" }
        let(:expected_prompt_version) { "^1.0.0" }

        before do
          stub_feature_flags(incident_fail_over_generation_provider: false)
          stub_feature_flags(claude_3_5_sonnet_20241022_for_code_gen: false)
        end

        it 'returns expected request params' do
          expect(subject.request_params).to eq(expected_request_params)
        end
      end

      context 'when failed over' do
        let(:expected_saas) { true }
        let(:expected_prompt_id) { "code_suggestions/generations" }
        let(:expected_prompt_version) { "2.0.0" }

        before do
          stub_feature_flags(incident_fail_over_generation_provider: true)
        end

        it 'returns expected request params' do
          expect(subject.request_params).to eq(expected_request_params)
        end
      end
    end

    context 'when all parameters are blank' do
      let(:instruction) { nil }
      let(:context) { nil }
      let(:current_file_params) { nil }
      let(:stream) { false }

      let(:expected_file_name) { '' }
      let(:expected_content_above_cursor) { nil }
      let(:expected_content_below_cursor) { nil }
      let(:expected_language_identifier) { '' }
      let(:expected_examples_array) { [] }
      let(:expected_trimmed_content_above_cursor) { '' }
      let(:expected_trimmed_content_below_cursor) { '' }
      let(:expected_libraries) { [] }
      let(:expected_user_instruction) { 'Generate the best possible code based on instructions.' }
      let(:expected_related_files) { [] }
      let(:expected_related_snippets) { [] }
      let(:expected_stream) { false }
      let(:expected_saas) { true }
      let(:expected_prompt_id) { "code_suggestions/generations" }
      let(:expected_prompt_version) { "2.0.0" }

      it 'returns expected request params' do
        expect(subject.request_params).to eq(expected_request_params)
      end

      it 'does not track an X-Ray event' do
        expect(Gitlab::InternalEvents).not_to receive(:track_event)

        subject.request_params
      end
    end
  end
  # rubocop:enable RSpec/MultipleMemoizedHelpers
end
