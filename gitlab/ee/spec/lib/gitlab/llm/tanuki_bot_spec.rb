# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Llm::TanukiBot, feature_category: :duo_chat do
  let_it_be(:user) { create(:user) }

  describe '.enabled_for?', :use_clean_rails_redis_caching do
    let_it_be_with_reload(:group) { create(:group) }
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }

    context 'when user present and container is not present' do
      where(:ai_duo_chat_switch_enabled, :allowed, :result) do
        [
          [true, true, true],
          [true, false, false],
          [false, true, false],
          [false, false, false]
        ]
      end

      with_them do
        before do
          stub_feature_flags(ai_duo_chat_switch: ai_duo_chat_switch_enabled)
          allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:user).with(user: user)
                                                                            .and_return(authorizer_response)
        end

        it 'returns correct result' do
          expect(described_class.enabled_for?(user: user)).to be(result)
        end
      end
    end

    context 'when user and container are both present' do
      where(:ai_duo_chat_switch_enabled, :allowed, :result) do
        [
          [true, true, true],
          [true, false, false],
          [false, true, false],
          [false, false, false]
        ]
      end

      with_them do
        before do
          stub_feature_flags(ai_duo_chat_switch: ai_duo_chat_switch_enabled)
          allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:container).with(user: user, container: group)
                                                                                 .and_return(authorizer_response)
        end

        it 'returns correct result' do
          expect(described_class.enabled_for?(user: user, container: group)).to be(result)
        end
      end
    end

    context 'when user is not present' do
      it 'returns false' do
        expect(described_class.enabled_for?(user: nil)).to be(false)
      end
    end
  end

  describe '.show_breadcrumbs_entry_point' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }
    let(:allowed) { true }

    before do
      allow(described_class).to receive(:chat_enabled?).with(user)
                                                       .and_return(ai_features_enabled_for_user)
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer).to receive(:user).with(user: user)
                                                                                 .and_return(authorizer_response)
    end

    where(:container, :ai_features_enabled_for_user, :allowed, :result) do
      [
        [:project, true, true, true],
        [:project, true, false, false],
        [:project, false, false, false],
        [:project, false, true, false],
        [:group, true, true, true],
        [:group, true, false, false],
        [:group, false, false, false],
        [:group, false, true, false],
        [nil, true, true, false],
        [nil, true, false, false],
        [nil, false, false, false],
        [nil, false, true, false]
      ]
    end

    with_them do
      it 'returns correct result' do
        expect(described_class.show_breadcrumbs_entry_point?(user: user, container: container)).to be(result)
      end
    end
  end

  describe '.chat_disabled_reason' do
    let(:authorizer_response) { instance_double(Gitlab::Llm::Utils::Authorizer::Response, allowed?: allowed) }
    let(:container) { build_stubbed(:group) }

    before do
      allow(Gitlab::Llm::Chain::Utils::ChatAuthorizer)
        .to receive(:container).with(container: container, user: user)
                               .and_return(authorizer_response)
    end

    context 'when chat is allowed' do
      let(:allowed) { true }

      it 'returns nil' do
        expect(described_class.chat_disabled_reason(user: user, container: container)).to be(nil)
      end
    end

    context 'when chat is not allowed' do
      let(:allowed) { false }

      context 'with a group' do
        it 'returns group' do
          expect(described_class.chat_disabled_reason(user: user, container: container)).to be(:group)
        end
      end

      context 'with a project' do
        let(:container) { build_stubbed(:project) }

        it 'returns project' do
          expect(described_class.chat_disabled_reason(user: user, container: container)).to be(:project)
        end
      end

      context 'without a container' do
        let(:container) { nil }

        it 'returns nil' do
          expect(described_class.chat_disabled_reason(user: user, container: container)).to be(nil)
        end
      end
    end
  end

  describe '.resource_id' do
    let(:issue) { build_stubbed(:issue) }

    context 'with current context including resource_id' do
      before do
        Gitlab::ApplicationContext.push(ai_resource: issue.to_global_id)
      end

      it 'returns the ai_resource from the current context' do
        expect(described_class.resource_id).to eq(issue.to_global_id)
      end
    end

    context 'with current context not including resource_id' do
      it 'returns nil when ai_resource is not present in the context' do
        expect(described_class.resource_id).to be_nil
      end
    end
  end

  describe '.project_id' do
    let_it_be(:project) { create(:project) }

    context 'with current context including project_id' do
      before do
        ::Gitlab::ApplicationContext.push(project: project)
      end

      it 'returns the global ID of the project when found' do
        expect(described_class.project_id).to eq(project.to_global_id)
      end
    end

    context 'when project is not found' do
      before do
        ::Gitlab::ApplicationContext.push(project: 'non_existent_project')
      end

      it 'returns nil' do
        expect(described_class.project_id).to be_nil
      end
    end

    context 'when project is not present in the context' do
      it 'returns nil' do
        expect(described_class.project_id).to be_nil
      end
    end
  end
end
