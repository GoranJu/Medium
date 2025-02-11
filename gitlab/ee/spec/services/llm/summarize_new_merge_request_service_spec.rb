# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::SummarizeNewMergeRequestService, :saas, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }

  let(:summarize_new_merge_request_enabled) { true }
  let(:current_user) { user }

  describe '#perform' do
    include_context 'with ai features enabled for group'

    before_all do
      group.add_guest(user)
    end

    before do
      allow(Ability).to receive(:allowed?).and_call_original
      allow(Ability)
        .to receive(:allowed?)
        .with(user, :summarize_new_merge_request, project)
        .and_return(summarize_new_merge_request_enabled)
      allow(user).to receive(:allowed_to_use?).with(:summarize_new_merge_request).and_return(true)
    end

    subject { described_class.new(current_user, project, {}).execute }

    it_behaves_like 'schedules completion worker' do
      subject { described_class.new(current_user, project, options) }

      let(:options) { {} }
      let(:resource) { project }
      let(:action_name) { :summarize_new_merge_request }
    end

    context 'when user is not member of project group' do
      let(:current_user) { create(:user) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when general feature flag is disabled' do
      before do
        stub_feature_flags(ai_global_switch: false)
      end

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when project is not a project' do
      let(:project) { create(:epic, group: group) }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end

    context 'when user has no ability to summarize_new_merge_request' do
      let(:summarize_new_merge_request_enabled) { false }

      it { is_expected.to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
    end
  end
end
