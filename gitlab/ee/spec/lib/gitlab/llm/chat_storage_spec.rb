# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::ChatStorage, :clean_gitlab_redis_chat, feature_category: :duo_chat do
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
  let(:redis_storage) { Gitlab::Llm::ChatStorage::Redis.new(user, agent_version_id) }
  let(:postgres_storage) { Gitlab::Llm::ChatStorage::Postgresql.new(user, agent_version_id) }

  subject { described_class.new(user, agent_version_id) }

  describe '#add' do
    it 'stores the message in PostgreSQL' do
      subject.add(message)

      expect(postgres_storage.messages).to include(message)
      expect(redis_storage.messages).to be_empty
    end

    context 'when feature flag duo_chat_drop_redis_storage is disabled' do
      before do
        stub_feature_flags(duo_chat_drop_redis_storage: false)
      end

      it 'updates Redis storage as well' do
        subject.add(message)

        expect(redis_storage.messages).to include(message)
      end
    end
  end

  describe '#update_message_extras' do
    let(:message) { build(:ai_chat_message, payload) }
    let(:another_message) { build(:ai_chat_message) }
    let(:resource_content) { 'message content' }
    let(:key) { 'resource_content' }
    let(:duo_chat_drop_redis_storage_enabled) { true }

    before do
      stub_feature_flags(duo_chat_drop_redis_storage: duo_chat_drop_redis_storage_enabled)

      subject.add(message)
      subject.add(another_message)
    end

    it 'updates message extras in PostgreSQL storage' do
      subject.update_message_extras(message.request_id, key, resource_content)

      expect(postgres_storage.messages.find { |m| m.request_id == message.request_id }.extras[key])
        .to eq(resource_content)
      expect(postgres_storage.messages.find { |m| m.request_id == another_message.request_id })
        .to eq(another_message)
    end

    context 'when feature flag duo_chat_drop_redis_storage is disabled' do
      let(:duo_chat_drop_redis_storage_enabled) { false }

      it 'updates Redis storage as well' do
        subject.update_message_extras(message.request_id, key, resource_content)

        expect(redis_storage.messages.find { |m| m.request_id == message.request_id }.extras[key])
          .to eq(resource_content)
        expect(redis_storage.messages.find { |m| m.request_id == another_message.request_id })
          .to eq(another_message)
      end
    end

    context 'when the given request_id is not found' do
      it 'does not update if the message' do
        expect do
          subject.update_message_extras('nonexistent_id', key, resource_content)
        end.not_to change { subject.messages.map(&:extras) }
      end
    end

    context 'when the key is not supported' do
      let(:key) { 'invalid_key' }

      it 'raises an ArgumentError' do
        expect do
          subject.update_message_extras(message.request_id, key, resource_content)
        end.to raise_error(ArgumentError, "The key #{key} is not supported")
      end
    end
  end

  describe '#set_has_feedback' do
    it 'updates the feedback flag in PostgreSQL' do
      subject.add(message)
      subject.set_has_feedback(message)

      expect(subject.messages.find { |m| m.id == message.id }.extras['has_feedback']).to be(true)
      expect(postgres_storage.messages.first.extras['has_feedback']).to be true
    end

    context 'when feature flag duo_chat_drop_redis_storage is disabled' do
      before do
        stub_feature_flags(duo_chat_drop_redis_storage: false)
      end

      it 'updates Redis storage as well' do
        subject.add(message)
        subject.set_has_feedback(message)

        expect(redis_storage.messages.first.extras['has_feedback']).to be true
      end
    end
  end

  shared_examples_for '#messages' do
    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'assistant', request_id: '2')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant', request_id: '3')))
    end

    it 'returns all records for this user' do
      expect(subject.messages.map(&:content)).to eq(%w[msg1 msg2 msg3])
    end

    it 'a message contains additional context' do
      expect(subject.messages.last.extras['additional_context']).to eq(payload[:additional_context].to_a)
    end
  end

  it_behaves_like '#messages'

  shared_examples_for '#messages_by' do
    let(:filters) { {} }

    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'assistant', request_id: '2')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant', request_id: '3')))
    end

    it 'returns all records for this user' do
      expect(subject.messages_by(filters).map(&:content)).to eq(%w[msg1 msg2 msg3])
    end

    context 'when filtering by role' do
      let(:filters) { { roles: ['user'] } }

      it 'returns only records for this role' do
        expect(subject.messages_by(filters).map(&:content)).to eq(%w[msg1])
      end
    end

    context 'when filtering by request_ids' do
      let(:filters) { { request_ids: %w[2 3] } }

      it 'returns only records with the same request_id' do
        expect(subject.messages_by(filters).map(&:content)).to eq(%w[msg2 msg3])
      end
    end
  end

  it_behaves_like '#messages_by'

  shared_examples_for '#last_conversation' do
    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user', request_id: '3')))
    end

    it 'returns from current history' do
      expect(subject).to receive(:last_conversation).and_call_original
      expect(subject.last_conversation.map(&:content)).to eq(%w[msg1 msg2])
    end
  end

  it_behaves_like '#last_conversation'

  shared_examples_for '.last_conversation' do
    let(:result) { described_class.last_conversation(messages).map(&:content) }

    context 'when there is no /reset message' do
      let(:messages) do
        [
          build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')),
          build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user', request_id: '3'))
        ]
      end

      it 'returns all records for this user' do
        expect(result).to eq(%w[msg1 msg2])
      end
    end

    context 'when there is /reset message' do
      let(:messages) do
        [
          build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')),
          build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: 'msg3', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: 'msg5', role: 'user', request_id: '3')),
          build(:ai_chat_message, payload.merge(content: 'msg6', role: 'user', request_id: '3'))
        ]
      end

      it 'returns all records for this user since last /reset message' do
        expect(result).to eq(%w[msg5 msg6])
      end
    end

    context 'when there is /reset message as the last message' do
      let(:messages) do
        [
          build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')),
          build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3'))
        ]
      end

      it 'returns all records for this user since last /reset message' do
        expect(result).to be_empty
      end
    end
  end

  it_behaves_like '.last_conversation'

  describe '#clear!' do
    before do
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg1', role: 'user', request_id: '1')))
      subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
      subject.add(build(:ai_chat_message, payload.merge(content: 'msg3', role: 'user', request_id: '3')))
      subject.add(build(:ai_chat_message, payload.merge(content: '/reset', role: 'user', request_id: '3')))
    end

    it 'clears messages from PostgreSQL' do
      expect_next_instance_of(Gitlab::Llm::ChatStorage::Redis) do |redis|
        expect(redis).not_to receive(:clear!)
      end

      subject.clear!

      expect(subject.messages).to be_empty
      expect(redis_storage.messages).to be_empty
      expect(postgres_storage.messages).to be_empty
    end

    context 'when feature flag duo_chat_drop_redis_storage is disabled' do
      before do
        stub_feature_flags(duo_chat_drop_redis_storage: false)
      end

      it 'updates Redis storage as well' do
        expect_next_instance_of(Gitlab::Llm::ChatStorage::Redis) do |redis|
          expect(redis).to receive(:clear!)
        end

        subject.clear!
      end
    end
  end

  shared_examples_for '#messages_up_to' do
    let(:messages) do
      [
        build(:ai_chat_message, payload.merge(content: 'msg1', role: 'assistant')),
        build(:ai_chat_message, payload.merge(content: 'msg2', role: 'user')),
        build(:ai_chat_message, payload.merge(content: 'msg3', role: 'assistant'))
      ]
    end

    before do
      messages.each { |m| subject.add(m) }
    end

    it 'returns first n messages up to one with matching message id' do
      expect(subject.messages_up_to(messages[1].id)).to eq(messages.first(2))
    end

    it 'returns [] if message id is not found' do
      expect(subject.messages_up_to('missing id')).to eq([])
    end
  end

  it_behaves_like '#messages_up_to'
end
