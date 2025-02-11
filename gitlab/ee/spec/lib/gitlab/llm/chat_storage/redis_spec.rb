# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatStorage::Redis, :clean_gitlab_redis_chat, feature_category: :duo_chat do
  let_it_be(:organization) { create(:organization) }
  let_it_be(:user) { create(:user, organizations: [organization]) }
  let_it_be(:request_id) { 'uuid' }
  let_it_be(:timestamp) { Time.current.to_s }
  let(:payload) do
    {
      timestamp: timestamp,
      request_id: request_id,
      errors: ['some error1', 'another error'],
      role: 'user',
      content: 'response',
      user: user,
      referer_url: 'http://127.0.0.1:3000',
      additional_context: Gitlab::Llm::AiMessageAdditionalContext.new(
        [
          { category: 'file', id: 'additional_context.rb', content: 'puts "additional context"' },
          { category: 'snippet', id: 'print_context_method', content: 'def additional_context; puts "context"; end' }
        ]
      )
    }
  end

  let_it_be(:agent_version_id) { 1 }
  let(:message) { build(:ai_chat_message, payload) }

  subject(:storage) { described_class.new(user, agent_version_id) }

  describe '#add' do
    it 'adds new message', :aggregate_failures do
      uuid = 'unique_id'

      expect(SecureRandom).to receive(:uuid).once.and_return(uuid)
      expect(storage.messages).to be_empty

      storage.add(message)

      last = storage.messages.last
      expect(last.id).to eq(uuid)
      expect(last.user).to eq(user)
      expect(last.agent_version_id).to eq(agent_version_id)
      expect(last.request_id).to eq(request_id)
      expect(last.errors).to match_array(['some error1', 'another error'])
      expect(last.content).to eq('response')
      expect(last.role).to eq('user')
      expect(last.ai_action).to eq('chat')
      expect(last.timestamp).not_to be_nil
      expect(last.referer_url).to eq('http://127.0.0.1:3000')
      expect(last.extras['additional_context']).to eq(payload[:additional_context].to_a)
    end

    context 'with MAX_MESSAGES limit' do
      before do
        stub_const('Gitlab::Llm::ChatStorage::Redis::MAX_MESSAGES', 2)
      end

      it 'removes oldest messages if we reach maximum message limit' do
        storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
        storage.add(build(:ai_chat_message, payload.merge(content: 'msg2')))

        expect(storage.messages.map(&:content)).to eq(%w[msg1 msg2])

        storage.add(build(:ai_chat_message, payload.merge(content: 'msg3')))

        expect(storage.messages.map(&:content)).to eq(%w[msg2 msg3])
      end
    end

    context 'when the content exceeds the text limit' do
      before do
        stub_const("::Gitlab::Llm::ChatStorage::Base::MAX_TEXT_LIMIT", 3)
      end

      it 'truncates the message content to MAX_TEXT_LIMIT' do
        storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))

        expect(storage.messages.last.content).to eq('msg')
      end
    end
  end

  describe '#set_has_feedback' do
    let(:message) { create(:ai_chat_message, user: user, agent_version_id: agent_version_id) }

    before do
      storage.add(message)
    end

    it 'marks the message as having feedback' do
      storage.set_has_feedback(message)

      expect(storage.messages.find { |m| m.id == message.id }.extras['has_feedback']).to be(true)
    end
  end

  describe '#messages' do
    before do
      storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
    end

    context 'when messages are correctly loaded' do
      before do
        storage.add(build(:ai_chat_message, payload.merge(content: 'msg2')))
      end

      it 'returns all messages for this user' do
        expect(storage.messages.map(&:content)).to eq(%w[msg1 msg2])
      end
    end
  end

  describe '#clear!' do
    before do
      storage.add(build(:ai_chat_message, payload.merge(content: 'msg1')))
      storage.add(build(:ai_chat_message, payload.merge(content: 'msg2')))
    end

    it 'removes all messages for this user' do
      storage.clear!
      expect(storage.messages).to be_empty
    end
  end
end
