# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/MultipleMemoizedHelpers -- there are lots of parameters at play
RSpec.describe Gitlab::Llm::Completions::Chat, feature_category: :duo_chat do
  include FakeBlobHelpers

  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository,  group: group) }
  let_it_be(:issue) { create(:issue, project: project) }
  let_it_be(:agent_version) { create(:ai_agent_version) }

  let(:resource) { issue }
  let(:expected_container) { resource.try(:resource_parent) }
  let(:content) { 'Summarize issue' }
  let(:ai_request) { instance_double(Gitlab::Llm::Chain::Requests::AiGateway) }
  let(:blob) { fake_blob(path: 'file.md') }
  let(:extra_resource) { { blob: blob } }
  let(:started_at) { Gitlab::Utils::System.real_time }
  let(:current_file) do
    {
      file_name: 'test.py',
      selected_text: 'selected',
      content_above_cursor: 'content_above_cursor',
      content_below_cursor: 'content_below_cursor'
    }
  end

  let(:additional_context) do
    [
      { category: 'snippet', id: 'hello world', content: 'puts "Hello, world"', metadata: {} }
    ]
  end

  let(:options) do
    {
      content: content,
      extra_resource: extra_resource,
      current_file: current_file,
      agent_version_id: agent_version.id,
      started_at: started_at,
      additional_context: additional_context
    }
  end

  let(:container) { resource.try(:resource_parent) }
  let(:context) do
    Gitlab::Llm::Chain::GitlabContext.new(
      container: container,
      current_user: user,
      resource: resource,
      request_id: 'uuid',
      ai_request: ai_request,
      current_file: current_file,
      agent_version: agent_version,
      additional_context: additional_context
    )
  end

  let(:categorize_service) { instance_double(::Llm::ExecuteMethodService) }
  let(:categorize_service_params) { { question: content, request_id: 'uuid', message_id: prompt_message.id } }

  let(:answer) do
    ::Gitlab::Llm::Chain::Answer.new(
      status: :ok, context: context, content: content, tool: nil, is_final: true
    )
  end

  let(:response_handler) { instance_double(Gitlab::Llm::ResponseService) }
  let(:stream_response_handler) { nil }

  let(:thread) { create(:ai_conversation_thread, user: user) }
  let(:prompt_message) do
    build(:ai_chat_message, user: user, resource: resource, request_id: 'uuid', content: content, thread: thread)
  end

  let(:tools) do
    [
      ::Gitlab::Llm::Chain::Tools::BuildReader,
      ::Gitlab::Llm::Chain::Tools::IssueReader,
      ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
      ::Gitlab::Llm::Chain::Tools::EpicReader,
      ::Gitlab::Llm::Chain::Tools::MergeRequestReader
    ]
  end

  subject { described_class.new(prompt_message, nil, **options).execute }

  shared_examples 'success' do
    it 'calls the SingleAction Agent with the right parameters', :snowplow do
      expected_params = [
        user_input: content,
        thread: thread,
        tools: match_array(tools),
        context: context,
        response_handler: response_handler,
        stream_response_handler: stream_response_handler
      ]

      expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
        expect(instance).to receive(:execute).and_return(answer)
      end

      expect(response_handler).to receive(:execute)
      expect(::Gitlab::Llm::ResponseService).to receive(:new)
        .with(context, { request_id: 'uuid', ai_action: :chat, thread: thread })
        .and_return(response_handler)
      expect(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
        .with(current_user: user, container: expected_container, resource: resource, ai_request: ai_request,
          extra_resource: extra_resource, request_id: 'uuid', current_file: current_file, agent_version: agent_version,
          started_at: started_at,
          additional_context: additional_context)
        .and_return(context)
      expect(categorize_service).to receive(:execute)
      expect(::Llm::ExecuteMethodService).to receive(:new)
        .with(user, user, :categorize_question, categorize_service_params)
        .and_return(categorize_service)

      subject

      expect_snowplow_event(
        category: described_class.to_s,
        label: "IssueReader",
        action: 'process_gitlab_duo_question',
        property: 'uuid',
        namespace: container,
        user: user,
        value: 1
      )
    end

    context 'when client_subscription_id is set' do
      let(:prompt_message) do
        build(:ai_chat_message, user: user, resource: resource, thread: thread,
          request_id: 'uuid', client_subscription_id: 'someid', content: content)
      end

      let(:stream_response_handler) { instance_double(Gitlab::Llm::ResponseService) }

      it 'correctly initializes response handlers' do
        expected_params = [
          user_input: content,
          thread: thread,
          tools: an_instance_of(Array),
          context: an_instance_of(Gitlab::Llm::Chain::GitlabContext),
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end

        expect(response_handler).to receive(:execute)
        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(
          an_instance_of(Gitlab::Llm::Chain::GitlabContext), { request_id: 'uuid', ai_action: :chat, thread: thread }
        ).and_return(response_handler)

        expect(::Gitlab::Llm::ResponseService).to receive(:new).with(
          an_instance_of(Gitlab::Llm::Chain::GitlabContext),
          { request_id: 'uuid', ai_action: :chat, client_subscription_id: 'someid', thread: thread }
        ).and_return(stream_response_handler).twice
        expect(stream_response_handler).to receive(:execute).with(response: anything, save_message: false)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new)
          .with(user, user, :categorize_question, categorize_service_params)
          .and_return(categorize_service)

        subject
      end
    end

    context 'with unsuccessful response' do
      let(:answer) do
        ::Gitlab::Llm::Chain::Answer.new(
          status: :error, context: context, content: content, tool: nil, is_final: true
        )
      end

      it 'sends process_gitlab_duo_question snowplow event with value eql 0' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end

        allow(::Gitlab::Llm::Chain::GitlabContext).to receive(:new).and_return(context)
        expect(categorize_service).to receive(:execute)
        expect(::Llm::ExecuteMethodService).to receive(:new)
         .with(user, user, :categorize_question, categorize_service_params)
         .and_return(categorize_service)

        subject

        expect_snowplow_event(
          category: described_class.to_s,
          label: "IssueReader",
          action: 'process_gitlab_duo_question',
          property: 'uuid',
          namespace: container,
          user: user,
          value: 0
        )
      end
    end
  end

  describe '.initialize' do
    subject { described_class.new(prompt_message, nil, **options) }

    it 'trims additional context' do
      expect(::CodeSuggestions::Context).to receive(:new).with(additional_context).and_call_original

      subject
    end
  end

  describe '#execute' do
    before do
      allow(Gitlab::Llm::Chain::Requests::AiGateway).to receive(:new).and_return(ai_request)
      allow(context).to receive(:tools_used).and_return([Gitlab::Llm::Chain::Tools::IssueReader::Executor])
      stub_saas_features(duo_chat_categorize_question: true)
      stub_feature_flags(ai_commit_reader_for_chat: false)
    end

    context 'when resource is an issue' do
      it_behaves_like 'success'
    end

    context 'when resource is a user' do
      let(:container) { nil }
      let(:expected_container) { nil }
      let_it_be(:resource) { user }

      it_behaves_like 'success'
    end

    context 'when resource is nil' do
      let(:resource) { nil }
      let(:expected_container) { nil }

      it_behaves_like 'success'
    end

    shared_examples_for 'tool behind a feature flag' do
      it 'calls zero shot agent with selected tools' do
        expected_params = [
          user_input: content,
          thread: thread,
          tools: match_array(tools),
          context: context,
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
          expect(instance).to receive(:execute).and_return(answer)
        end
        expect(response_handler).to receive(:execute)
        expect(::Gitlab::Llm::ResponseService).to receive(:new)
          .with(context, { ai_action: :chat, request_id: 'uuid', thread: thread })
          .and_return(response_handler)
        expect(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
          .with(current_user: user, container: expected_container, resource: resource,
            ai_request: ai_request, extra_resource: extra_resource, request_id: 'uuid',
            started_at: started_at,
            current_file: current_file, agent_version: agent_version, additional_context: additional_context)
          .and_return(context)
        # This is temporarily commented out due to the following production issue:
        # https://gitlab.com/gitlab-com/gl-infra/production/-/issues/18191
        # Since the `#response_post_processing` call is commented out, this should be too.
        # expect(categorize_service).to receive(:execute)
        # expect(Llm::ExecuteMethodService).to receive(:new)
        #   .with(user, user, :categorize_question, categorize_service_params)
        #   .and_return(categorize_service)

        subject
      end
    end

    context 'when on self-managed cloud-connected instance' do
      before do
        allow(::CloudConnector).to receive(:self_managed_cloud_connected?).and_return(true)
      end

      it 'does not push expanded ai logging feature flag to AI Gateway' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        expect(::Gitlab::AiGateway).not_to receive(:push_feature_flag).with(:expanded_ai_logging, user)

        subject
      end
    end

    context 'with commit reader allowed' do
      before do
        stub_feature_flags(ai_commit_reader_for_chat: true)
        allow(ai_request).to receive(:request)
        allow(::Gitlab::AiGateway).to receive(:push_feature_flag)
        allow(::CloudConnector).to receive(:self_managed_cloud_connected?).and_return(false)
      end

      let(:tools) do
        [
          ::Gitlab::Llm::Chain::Tools::BuildReader,
          ::Gitlab::Llm::Chain::Tools::IssueReader,
          ::Gitlab::Llm::Chain::Tools::GitlabDocumentation,
          ::Gitlab::Llm::Chain::Tools::EpicReader,
          ::Gitlab::Llm::Chain::Tools::MergeRequestReader,
          ::Gitlab::Llm::Chain::Tools::CommitReader
        ]
      end

      it_behaves_like 'tool behind a feature flag'

      it 'pushes feature flag to AI Gateway' do
        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        expect(::Gitlab::AiGateway).to receive(:push_feature_flag)
          .with(:ai_commit_reader_for_chat, user).and_return(:ai_commit_reader_for_chat)
        expect(::Gitlab::AiGateway).to receive(:push_feature_flag)
         .with(:expanded_ai_logging, user).and_return(:expanded_ai_logging)

        subject
      end
    end

    context 'when message is a slash command' do
      shared_examples_for 'slash command execution' do
        let(:executor) { instance_double(Gitlab::Llm::Chain::Tools::ExplainCode::Executor) }

        before do
          allow(executor).to receive(:execute).and_return(answer)
        end

        it 'calls directly a tool' do
          expected_params = {
            context: an_instance_of(::Gitlab::Llm::Chain::GitlabContext),
            options: { input: content },
            stream_response_handler: nil,
            command: an_instance_of(::Gitlab::Llm::Chain::SlashCommand)
          }

          expect(::Gitlab::Duo::Chat::ReactExecutor).not_to receive(:new)
          expect(expected_tool)
            .to receive(:new).with(expected_params).and_return(executor)

          subject
        end

        it 'tracks slash command event', :snowplow do
          expect(expected_tool).to receive(:new).and_return(executor)

          subject

          expect_snowplow_event(
            category: described_class.to_s,
            action: 'process_gitlab_duo_slash_command',
            label: command,
            property: 'uuid',
            namespace: container,
            user: user,
            value: 1
          )
        end
      end

      let(:content) { "#{command} something" }

      context 'when /explain is used' do
        let(:command) { '/explain' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::ExplainCode::Executor }
        end
      end

      context 'when /troubleshoot is used' do
        let(:command) { '/troubleshoot' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::TroubleshootJob::Executor }
        end
      end

      context 'when /tests is used' do
        let(:command) { '/tests' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::WriteTests::Executor }
        end
      end

      context 'when /refactor is used' do
        let(:command) { '/refactor' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::RefactorCode::Executor }
        end
      end

      context 'when /fix is used' do
        let(:command) { '/fix' }

        it_behaves_like 'slash command execution' do
          let(:expected_tool) { ::Gitlab::Llm::Chain::Tools::FixCode::Executor }
        end
      end

      context 'when slash command does not exist' do
        let(:command) { '/explain2' }

        it 'process the message with zero shot agent' do
          expect_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
            expect(instance).to receive(:execute).and_return(answer)
          end
          expect(::Gitlab::Llm::Chain::Tools::ExplainCode::Executor).not_to receive(:new)

          subject
        end
      end
    end

    context 'with on-premises GitLab instance' do
      before do
        stub_saas_features(duo_chat_categorize_question: false)
      end

      it 'does not execute question categorization' do
        expected_params = [
          user_input: content,
          thread: thread,
          tools: match_array(tools),
          context: context,
          response_handler: response_handler,
          stream_response_handler: stream_response_handler
        ]

        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor, *expected_params) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end

        allow(response_handler).to receive(:execute)
        allow(::Gitlab::Llm::ResponseService).to receive(:new)
          .with(context, { request_id: 'uuid', ai_action: :chat, thread: thread })
          .and_return(response_handler)
        allow(::Gitlab::Llm::Chain::GitlabContext).to receive(:new)
          .with(current_user: user, container: expected_container, resource: resource, ai_request: ai_request,
            extra_resource: extra_resource, request_id: 'uuid', current_file: current_file,
            started_at: started_at,
            agent_version: agent_version, additional_context: additional_context)
          .and_return(context)

        expect(categorize_service).not_to receive(:execute)

        subject
      end
    end

    describe "duo chat prompt caching" do
      before do
        allow(::Gitlab::AiGateway).to receive(:push_feature_flag)

        allow_next_instance_of(::Gitlab::Duo::Chat::ReactExecutor) do |instance|
          allow(instance).to receive(:execute).and_return(answer)
        end
      end

      it 'pushes duo chat prompt caching FF to AI Gateway when enabled' do
        stub_feature_flags(enable_anthropic_prompt_caching: true)

        expect(::Gitlab::AiGateway).to receive(:push_feature_flag).with(:enable_anthropic_prompt_caching, user)

        subject
      end

      it "doesn't push duo chat prompt caching FF to AI Gateway when disabled" do
        stub_feature_flags(enable_anthropic_prompt_caching: false)

        expect(::Gitlab::AiGateway).not_to receive(:push_feature_flag).with(:enable_anthropic_prompt_caching, user)

        subject
      end
    end
  end
end
# rubocop:enable RSpec/MultipleMemoizedHelpers
