# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Llm::MergeRequests::SummarizeReviewService, :saas, feature_category: :code_review_workflow do
  let_it_be(:user) { create(:user) }
  let_it_be(:user_2) { create(:user) }
  let_it_be_with_reload(:group) { create(:group_with_plan, :public, plan: :ultimate_plan) }
  let_it_be(:project) { create(:project, :public, group: group) }
  let_it_be(:merge_request) { create(:merge_request, source_project: project, target_project: project, author: user) }

  let_it_be(:merge_request_note) { create(:note, noteable: merge_request, project: project, author: user) }
  let!(:draft_note_by_current_user) { create(:draft_note, merge_request: merge_request, author: user) }
  let!(:draft_note_by_random_user) { create(:draft_note, merge_request: merge_request) }
  let(:options) { {} }

  describe "#perform" do
    before do
      stub_ee_application_setting(should_check_namespace_plan: true)
      stub_licensed_features(summarize_my_mr_code_review: true, ai_features: true, experimental_features: true)
      allow(user).to receive(:allowed_to_use?).with(:summarize_review).and_return(true)

      group.add_developer(user)

      group.namespace_settings.update!(experiment_features_enabled: true)
    end

    subject { described_class.new(user, merge_request, options) }

    context "when testing validity" do
      shared_examples "returns an error" do
        it { expect(subject.execute).to be_error.and have_attributes(message: eq(described_class::INVALID_MESSAGE)) }
      end

      context "when resource is not a merge request" do
        subject { described_class.new(user, create(:issue), options) }

        it_behaves_like "returns an error"
      end

      context "when :ai_global_switch is disabled" do
        before do
          stub_feature_flags(ai_global_switch: false)
        end

        it_behaves_like "returns an error"
      end

      context "when merge request has no associated draft notes" do
        before do
          allow(merge_request).to receive(:draft_notes).and_return(DraftNote.none)
        end

        it_behaves_like "returns an error"
      end
    end

    it_behaves_like 'schedules completion worker' do
      let(:resource) { merge_request }
      let(:action_name) { :summarize_review }
    end
  end
end
