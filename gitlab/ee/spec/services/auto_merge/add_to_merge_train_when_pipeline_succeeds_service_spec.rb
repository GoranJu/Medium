# frozen_string_literal: true

require 'spec_helper'

RSpec.describe AutoMerge::AddToMergeTrainWhenPipelineSucceedsService, feature_category: :merge_trains do
  let_it_be(:project, reload: true) { create(:project, :repository) }
  let_it_be(:user) { create(:user) }

  let(:service) { described_class.new(project, user) }

  let(:merge_request) do
    create(:merge_request, :with_merge_request_pipeline,
      source_project: project, source_branch: 'feature',
      target_project: project, target_branch: 'master')
  end

  let(:pipeline) { merge_request.reload.all_pipelines.first }

  before do
    project.add_maintainer(user)
    project.update!(merge_pipelines_enabled: true, merge_trains_enabled: true)
    stub_licensed_features(merge_trains: true, merge_pipelines: true)
    allow(AutoMergeProcessWorker).to receive(:perform_async)
    merge_request.update_head_pipeline
  end

  describe '#execute' do
    subject(:service_execute) { service.execute(merge_request) }

    it 'enables auto merge' do
      expect(SystemNoteService)
        .to receive(:add_to_merge_train_when_pipeline_succeeds)
        .with(merge_request, project, user, merge_request.diff_head_pipeline.sha)

      service_execute

      expect(merge_request).to be_auto_merge_enabled
    end
  end

  describe '#process' do
    subject(:service_process) { service.process(merge_request) }

    before do
      merge_request.merge_params['auto_merge_strategy'] =
        AutoMergeService::STRATEGY_ADD_TO_MERGE_TRAIN_WHEN_PIPELINE_SUCCEEDS
      service.execute(merge_request)
    end

    context 'when the latest pipeline in the merge request has succeeded' do
      before do
        pipeline.succeed!
      end

      it 'executes MergeTrainService' do
        expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
          expect(train_service).to receive(:execute).with(merge_request)
        end

        service_process
      end

      context 'when the merge request is in the middle of a mergeability check' do
        before do
          merge_request.mark_as_unchecked!
        end

        it 'executes MergeTrainService' do
          expect_next_instance_of(AutoMerge::MergeTrainService) do |train_service|
            expect(train_service).to receive(:execute).with(merge_request)
          end

          service_process
        end
      end

      context 'when user does not have permission to merge the merge request' do
        before do
          allow(merge_request).to receive(:can_be_merged_by?).with(user).and_return(false)
        end

        it 'aborts auto merge' do
          expect(service).to receive(:abort).once.and_call_original

          expect(SystemNoteService)
            .to receive(:abort_add_to_merge_train_when_pipeline_succeeds).once
            .with(merge_request, project, user, 'they do not have permission to merge the merge request.')

          service_process
        end
      end

      context 'when mergeability checks do not pass' do
        let(:identifier) { 'failed_check' }
        let(:failed_result) do
          Gitlab::MergeRequests::Mergeability::CheckResult.failed(payload: { identifier: identifier })
        end

        before do
          allow_next_instance_of(MergeRequests::Mergeability::CheckOpenStatusService) do |service|
            allow(service).to receive_messages(skip?: false, execute: failed_result)
          end
        end

        it 'aborts auto merge' do
          expect(service).to receive(:abort).once.and_call_original

          expect(SystemNoteService)
            .to receive(:abort_add_to_merge_train_when_pipeline_succeeds).once
            .with(
              merge_request,
              project,
              user,
              "the merge request cannot be merged. Failed mergeability check: #{identifier}"
            )

          service_process
        end
      end

      context 'when merge trains not enabled' do
        before do
          allow(merge_request.project).to receive(:merge_trains_enabled?).and_return(false)
        end

        it 'aborts auto merge' do
          expect(service).to receive(:abort).once.and_call_original

          expect(SystemNoteService)
            .to receive(:abort_add_to_merge_train_when_pipeline_succeeds).once
            .with(merge_request, project, user, 'merge trains are disabled for this project.')

          service_process
        end
      end

      context 'when diff head pipeline considered in progress' do
        before do
          allow(merge_request).to receive(:only_allow_merge_if_pipeline_succeeds?).and_return(true)
          allow(merge_request.diff_head_pipeline).to receive(:complete?).and_return(false)
        end

        it 'aborts auto merge' do
          expect(service).to receive(:abort).once.and_call_original
          expect(SystemNoteService)
            .to receive(:abort_add_to_merge_train_when_pipeline_succeeds).once
            .with(merge_request, project, user, 'the merge request currently has a pipeline in progress.')

          service_process
        end
      end

      context 'when MergeTrainService is not available_for mr but reason is unknown' do
        before do
          allow_next_instance_of(AutoMerge::MergeTrainService) do |mr_service|
            allow(mr_service).to receive(:available_for?).and_return(false)
          end
        end

        it 'aborts auto merge' do
          expect(service).to receive(:abort).once.and_call_original
          expect(SystemNoteService)
            .to receive(:abort_add_to_merge_train_when_pipeline_succeeds).once
            .with(merge_request, project, user, 'this merge request cannot be added to the merge train.')

          service_process
        end
      end
    end

    context 'when the latest pipeline in the merge request is running' do
      it 'does not initialize MergeTrainService' do
        expect(AutoMerge::MergeTrainService).not_to receive(:new)

        service_process
      end
    end
  end

  describe '#cancel' do
    subject(:service_cancel) { service.cancel(merge_request) }

    let(:merge_request) { create(:merge_request, :add_to_merge_train_when_pipeline_succeeds, merge_user: user) }

    it 'cancels auto merge' do
      expect(SystemNoteService)
        .to receive(:cancel_add_to_merge_train_when_pipeline_succeeds)
        .with(merge_request, project, user)

      service_cancel

      expect(merge_request).not_to be_auto_merge_enabled
    end
  end

  describe '#abort' do
    subject(:service_abort) { service.abort(merge_request, 'an error') }

    let(:merge_request) { create(:merge_request, :add_to_merge_train_when_pipeline_succeeds, merge_user: user) }

    context 'without merge train car' do
      it 'disables the auto-merge' do
        expect(SystemNoteService)
          .to receive(:abort_add_to_merge_train_when_pipeline_succeeds)
          .with(merge_request, project, user, 'an error')

        service_abort

        expect(merge_request).not_to be_auto_merge_enabled
      end
    end

    context 'with merge train car' do
      let(:merge_train_car) { create(:merge_train_car, merge_request: merge_request, target_project: project) }

      it 'aborts by destroying the running train car and canceling the pipeline' do
        expect(merge_train_car).not_to be_nil
        expect(SystemNoteService)
          .to receive(:abort_merge_train)
          .with(merge_request, project, user, 'an error')

        service_abort

        expect(merge_request).not_to be_auto_merge_enabled
        expect(merge_request.reload.merge_train_car).to be_nil
      end
    end
  end

  describe '#available_for?' do
    subject { service.available_for?(merge_request) }

    it { is_expected.to be(false) }

    context 'when merge trains option is disabled' do
      before do
        allow(merge_request.project).to receive(:merge_trains_enabled?).and_return(false)
      end

      it { is_expected.to be(false) }
    end

    context 'when the latest pipeline in the merge request is completed' do
      before do
        pipeline.succeed!
      end

      it { is_expected.to be(false) }
    end

    context 'when merge request is not mergeable' do
      before do
        merge_request.update!(title: merge_request.draft_title)
      end

      it { is_expected.to be(false) }
    end

    context 'when there is an open MR dependency' do
      before do
        stub_licensed_features(blocking_merge_requests: true)
        create(:merge_request_block, blocked_merge_request: merge_request)
      end

      it { is_expected.to be_falsy }
    end

    context 'when the user does not have permission to merge' do
      before do
        allow(merge_request).to receive(:can_be_merged_by?).and_return(false)
      end

      it { is_expected.to be_falsy }
    end
  end
end
