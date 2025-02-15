# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Resolvers::Ai::UserAvailableFeaturesResolver, feature_category: :duo_chat do
  include GraphqlHelpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project) }

  subject(:resolver) { resolve(described_class, obj: project, ctx: { current_user: current_user }) }

  describe '#resolve' do
    context 'when user is not authenticated' do
      let(:current_user) { nil }

      it 'returns an empty array' do
        expect(resolver).to eq([])
      end
    end

    context 'when user is authenticated' do
      let(:current_user) { user }

      context 'when duo chat is disabled' do
        before do
          stub_feature_flags(ai_duo_chat_switch: false)
        end

        it 'returns an empty array' do
          expect(resolver).to eq([])
        end
      end

      context 'when duo chat is enabled' do
        before do
          stub_feature_flags(ai_duo_chat_switch: true)
        end

        context 'when user does not have access to duo chat' do
          before do
            allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user,
              :allowed?).and_return(false)
          end

          it 'returns an empty array' do
            expect(resolver).to eq([])
          end
        end

        context 'when user has access to duo chat' do
          before do
            allow(::Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive_message_chain(:user,
              :allowed?).and_return(true)
            allow(current_user).to receive(:allowed_to_use?).and_return(true)
          end

          context 'when all context categories are enabled' do
            before do
              ::Ai::AdditionalContext::DUO_CHAT_CONTEXT_CATEGORIES.each_value do |category|
                stub_feature_flags("duo_include_context_#{category}": true)
              end
            end

            it 'returns all available features' do
              expected_features = ::Ai::AdditionalContext::DUO_CHAT_CONTEXT_CATEGORIES.values.map do |category|
                "include_#{category}_context"
              end

              expect(resolver).to match_array(expected_features)
            end
          end

          context 'when testing each context category individually' do
            feature_flags =
              {
                duo_include_context_file: 'include_file_context',
                duo_include_context_snippet: 'include_snippet_context',
                duo_include_context_merge_request: 'include_merge_request_context',
                duo_include_context_issue: 'include_issue_context',
                duo_include_context_dependency: 'include_dependency_context',
                duo_include_context_local_git: 'include_local_git_context'
              }

            feature_flags.each do |flag, feature|
              context "when only #{flag} is enabled" do
                before do
                  feature_flags.each_key { |f| stub_feature_flags(f => false) }
                  stub_feature_flags(flag => true)
                end

                it "returns only #{feature}" do
                  expect(Feature.enabled?(flag, current_user, type: :gitlab_com_derisk)).to be(true)
                  expect(resolver).to contain_exactly(feature)
                end
              end
            end
          end
        end
      end
    end
  end
end
