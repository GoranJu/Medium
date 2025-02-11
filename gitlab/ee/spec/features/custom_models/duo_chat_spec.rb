# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Duo Chat', :js, :requires_custom_models_setup, :sidekiq_inline,
  feature_category: :"self-hosted_models", quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/502971' do
  include_context 'with duo features enabled and ai chat available for self-managed'
  using RSpec::Parameterized::TableSyntax

  let_it_be(:user) { create(:user) }
  let(:service) { instance_double('::CloudConnector::SelfSigned::AvailableServiceData') }
  let(:answer) { "Mock response from mistral" }
  let!(:self_hosted_model) do
    create(:ai_self_hosted_model, name: 'mistral', model: :mistral, endpoint: ENV['LITELLM_PROXY_URL'])
  end

  let!(:ai_feature_setting) do
    create(:ai_feature_setting, self_hosted_model: self_hosted_model, feature: :duo_chat)
  end

  before do
    allow(::CloudConnector::AvailableServices).to receive(:find_by_name).and_return(service)
    allow(service).to receive_messages(access_token: 'token', allowed_for?: true, name: :duo_chat)
    allow(user).to receive(:allowed_by_namespace_ids).and_return(enabled_by_namespace_ids)
  end

  context 'for GitLab Duo features generally accessible on any page' do
    let!(:group) { create(:group) }

    before do
      group.add_owner(user)
      sign_in(user)
      visit group_path(group)
    end

    where(:question) do
      [
        'Who are you?', # Direct Question
        'How do I fork a project on GitLab?', # Question on GitLab Documentation
        lazy { compose_slash_command_question('/explain') } # A slash command
      ]
    end

    with_them do
      it 'returns response after asking a question' do
        open_chat
        chat_request(question)

        within_testid('chat-component') do
          expect(page).to have_content(question.strip)
          expect(page).to have_content(answer)
        end

        clear_chat
      end
    end
  end

  private

  def compose_slash_command_question(slash_command)
    <<~TEXT
      #{slash_command} def hello(name) puts "Hello, GitLab!" end
    TEXT
  end

  def open_chat
    click_button "GitLab Duo Chat"
  end

  def chat_request(question)
    send_keys(question)
    send_keys(:enter)
    wait_for_requests
  end

  def clear_chat
    send_keys('/clear')
    send_keys(:enter)
  end
end
