# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversation::Message, feature_category: :duo_chat do
  describe 'associations' do
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }
    it { is_expected.to belong_to(:thread).class_name('Ai::Conversation::Thread') }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:content) }
    it { is_expected.to validate_presence_of(:role) }
    it { is_expected.to validate_presence_of(:thread_id) }
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:role).with_values(user: 1, assistant: 2) }
  end

  describe 'scopes' do
    describe '.for_thread' do
      subject(:messages_for_thread) { described_class.for_thread(thread) }

      let(:thread) { create(:ai_conversation_thread) }
      let(:message1) { create(:ai_conversation_message, thread: thread) }
      let(:message2) { create(:ai_conversation_message, thread: thread) }
      let(:other_message) { create(:ai_conversation_message) }

      it 'returns messages for the specified thread' do
        expect(messages_for_thread).to match_array([message1, message2])
      end
    end

    describe '.for_message_xid' do
      subject(:for_message_xid) { described_class.for_message_xid(message_xid) }

      let_it_be(:message_xid) { SecureRandom.uuid }
      let_it_be(:message_with_xid) { create(:ai_conversation_message, message_xid: message_xid) }

      it 'returns message with the specified message_xid' do
        expect(for_message_xid).to eq([message_with_xid])
      end
    end

    describe '.ordered' do
      subject(:messages) { described_class.ordered }

      let!(:message1) { create(:ai_conversation_message) }
      let!(:message2) { create(:ai_conversation_message) }

      it 'returns messages ordered by id' do
        expect(messages).to eq([message1, message2])
      end
    end
  end

  describe '.recent' do
    subject(:messages) { described_class.recent(limit) }

    let_it_be(:message1) { create(:ai_conversation_message) }
    let_it_be(:message2) { create(:ai_conversation_message) }
    let_it_be(:message3) { create(:ai_conversation_message) }

    let(:limit) { 2 }

    it 'returns recent messages' do
      expect(messages).to eq([message2, message3])
    end

    context 'when limit is nil' do
      let(:limit) { nil }

      it 'returns recent messages without limit' do
        expect(messages).to eq([message1, message2, message3])
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :populate_organization_id' do
      let(:organization) { create(:organization) }
      let(:user) { create(:user, organizations: [organization]) }
      let(:thread) { create(:ai_conversation_thread, user: user, organization: organization) }

      it 'sets organization_id from thread' do
        message = described_class.create!(thread: thread, content: 'message', role: 'user')

        expect(message.organization_id).to eq(user.organizations.first.id)
      end
    end
  end

  context 'with loose foreign key on ai_conversation_threads.thread_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:ai_conversation_thread) }
      let_it_be(:model) { create(:ai_conversation_message, thread: parent) }
    end
  end
end
