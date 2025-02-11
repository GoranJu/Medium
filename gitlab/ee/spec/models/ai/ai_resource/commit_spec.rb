# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AiResource::Commit, feature_category: :duo_chat do
  let_it_be(:project) { create(:project, :public, :repository) }
  let_it_be(:commit) { project.commit }
  let(:user) { build(:user) }

  subject(:wrapped_commit) { described_class.new(user, commit) }

  describe '#serialize_for_ai' do
    it 'calls the serializations class' do
      expect(EE::CommitSerializer).to receive_message_chain(:new, :represent)
                                  .with(current_user: user, project: project)
                                  .with(commit, {
                                    user: user,
                                    notes_limit: 100,
                                    serializer: 'ai',
                                    resource: wrapped_commit
                                  })

      wrapped_commit.serialize_for_ai(content_limit: 100)
    end
  end

  describe '#current_page_type' do
    it 'returns type' do
      expect(wrapped_commit.current_page_type).to eq('commit')
    end
  end

  describe '#current_page_short_description' do
    it 'returns prompt' do
      expect(wrapped_commit.current_page_short_description)
        .to include("The title of the commit is '#{commit.title}'.")
    end

    context 'with mr for chat feature flag disabled' do
      before do
        stub_feature_flags(ai_commit_reader_for_chat: false)
      end

      it 'returns empty string' do
        expect(wrapped_commit.current_page_short_description)
          .to eq("")
      end
    end
  end
end
