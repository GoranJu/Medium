# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::MergeRequests::RequestReviewService, feature_category: :code_review_workflow do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:user) { ::Users::Internal.duo_code_review_bot }
  let_it_be(:merge_request) { create(:merge_request, reviewers: [user]) }
  let(:service) { described_class.new(project: merge_request.project, current_user: current_user) }

  before_all do
    merge_request.project.add_developer(current_user)
  end

  context 'when requesting review from duo code review bot' do
    context 'when AI review feature is not allowed' do
      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(false)
      end

      it 'does not call ::Llm::ReviewMergeRequestService' do
        expect(Llm::ReviewMergeRequestService).not_to receive(:new)

        service.execute(merge_request, user)
      end
    end

    context 'when AI review feature is allowed' do
      before do
        allow(merge_request).to receive(:ai_review_merge_request_allowed?).with(current_user).and_return(true)
      end

      it 'does not call ::Llm::ReviewMergeRequestService' do
        expect_next_instance_of(Llm::ReviewMergeRequestService, current_user, merge_request) do |svc|
          expect(svc).to receive(:execute)
        end

        service.execute(merge_request, user)
      end
    end
  end
end
