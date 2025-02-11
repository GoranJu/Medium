# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::ChatMessagesResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  describe '#resolve' do
    let_it_be(:project) { create(:project) }
    let_it_be(:user) { create(:user).tap { |u| project.add_developer(u) } }
    let_it_be(:another_user) { create(:user).tap { |u| project.add_developer(u) } }

    let(:args) { {} }

    subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: user }, args: args) }

    it 'returns empty' do
      expect(resolver).to eq([])
    end

    context 'when there is a message' do
      let!(:thread) { create(:ai_conversation_thread, user: user) }
      let!(:message) do
        create(:ai_conversation_message, created_at: Time.new(2020, 2, 2, 17, 30, 45, '+00:00'),
          thread: thread, message_xid: 'message_xid')
      end

      shared_examples_for 'message response' do
        it 'returns the message' do
          expect(resolver).to match([
            a_hash_including({
              "additional_context" => [],
              "ai_action" => "chat",
              "content" => "Message content",
              "errors" => {},
              "extras" => {},
              "id" => 'message_xid',
              "role" => "user",
              "timestamp" => message.created_at
            })
          ])
        end
      end

      it_behaves_like 'message response'

      context 'when thread_id is specified' do
        let(:args) { { thread_id: thread.to_global_id } }

        it_behaves_like 'message response'

        context 'when thread is not found' do
          let!(:thread) { create(:ai_conversation_thread, user: another_user) }

          it 'returns error' do
            expect_graphql_error_to_be_created(Gitlab::Graphql::Errors::ArgumentError,
              "Thread #{thread.id} is not found.") do
              resolver
            end
          end
        end
      end

      context 'when conversation_type is specified' do
        let(:args) { { conversation_type: 'duo_chat' } }

        it_behaves_like 'message response'

        context 'when thread is not found' do
          let!(:thread) { create(:ai_conversation_thread, user: another_user) }

          it 'returns empty' do
            expect(resolver).to eq([])
          end
        end
      end
    end
  end
end
