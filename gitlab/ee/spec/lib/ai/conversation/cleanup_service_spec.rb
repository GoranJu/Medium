# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::Conversation::CleanupService, feature_category: :duo_chat do
  describe '#execute' do
    let(:service) { described_class.new }

    context 'when there are expired threads' do
      let!(:expired_thread) { create(:ai_conversation_thread, :expired) }
      let!(:active_thread) { create(:ai_conversation_thread) }

      it 'deletes all expired threads' do
        expect { service.execute }.to change { Ai::Conversation::Thread.count }.from(2).to(1)

        expect(Ai::Conversation::Thread.exists?(expired_thread.id)).to be false
        expect(Ai::Conversation::Thread.exists?(active_thread.id)).to be true
      end
    end
  end
end
