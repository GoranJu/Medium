# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversation::Thread, type: :model, feature_category: :duo_chat do
  describe 'associations' do
    it { is_expected.to have_many(:messages).class_name('Ai::Conversation::Message') }
    it { is_expected.to belong_to(:organization).class_name('Organizations::Organization') }
    it { is_expected.to belong_to(:user) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:conversation_type) }
    it { is_expected.to validate_presence_of(:user_id) }
  end

  describe 'enums' do
    it 'defines enum' do
      is_expected.to define_enum_for(:conversation_type).with_values(
        duo_chat: 1,
        duo_code_review: 2,
        duo_quick_chat: 3
      )
    end
  end

  describe 'scopes' do
    describe '.expired' do
      subject(:expired_threads) { described_class.expired }

      let_it_be(:old_thread) { create(:ai_conversation_thread, last_updated_at: 31.days.ago) }
      let_it_be(:recent_thread) { create(:ai_conversation_thread, last_updated_at: 29.days.ago) }
      let_it_be(:current_thread) { create(:ai_conversation_thread, last_updated_at: Time.current) }

      it 'returns threads older than 30 days' do
        expect(expired_threads).to contain_exactly(old_thread)
      end
    end

    describe '.for_conversation_type' do
      subject(:threads) { described_class.for_conversation_type(:duo_chat) }

      let_it_be(:duo_chat_thread) { create(:ai_conversation_thread, conversation_type: :duo_chat) }

      it 'returns threads' do
        expect(threads).to contain_exactly(duo_chat_thread)
      end
    end

    describe '.ordered' do
      subject(:threads) { described_class.ordered }

      let_it_be(:thread_1) { create(:ai_conversation_thread, last_updated_at: 1.day.ago) }
      let_it_be(:thread_2) { create(:ai_conversation_thread) }

      it 'returns the recently interacted thread first' do
        expect(threads).to eq([thread_2, thread_1])
      end
    end
  end

  describe 'callbacks' do
    describe 'before_create :populate_organization_id' do
      let_it_be(:organization) { create(:organization) }

      let(:user) { create(:user, organizations: [organization]) }

      it 'assigns organization_id from user organization' do
        thread = described_class.create!(user: user, conversation_type: :duo_chat)

        expect(thread.organization_id).to eq(user.organizations.first.id)
      end

      context 'when user is not assigned to an organization' do
        let(:user) { create(:user, organizations: []) }

        it 'assigns organization_id from first found organization' do
          thread = described_class.create!(user: user, conversation_type: :duo_chat)

          expect(thread.organization_id).to eq(Organizations::Organization.first.id)
        end
      end
    end
  end

  it_behaves_like 'it has loose foreign keys' do
    let(:factory_name) { :ai_conversation_thread }
  end
end
