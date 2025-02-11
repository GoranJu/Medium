# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ConcurrencyLimit::ResumeWorker, feature_category: :scalability do
  subject(:worker) { described_class.new }

  let(:worker_with_concurrency_limit) { ElasticCommitIndexerWorker }
  let(:concurrent_workers) { 5 }

  describe '#perform' do
    before do
      allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:resume_processing!)
      allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
        .to receive(:concurrent_worker_count).and_return(concurrent_workers)
    end

    shared_examples 'report prometheus metrics' do |limit = described_class::BATCH_SIZE, queue_size = 10000|
      it do
        queue_size_gauge_double = instance_double(Prometheus::Client::Gauge)
        expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                  .with(:sidekiq_concurrency_limit_queue_jobs, anything, {}, :max)
                                                  .and_return(queue_size_gauge_double)

        allow(queue_size_gauge_double).to receive(:set).with({ worker: anything }, anything)
        expect(queue_size_gauge_double).to receive(:set).with({ worker: worker_with_concurrency_limit.name },
          queue_size)

        limit_gauge_double = instance_double(Prometheus::Client::Gauge)
        expect(Gitlab::Metrics).to receive(:gauge).at_least(:once)
                                                  .with(:sidekiq_concurrency_limit_max_concurrent_jobs, anything, {})
                                                  .and_return(limit_gauge_double)

        allow(limit_gauge_double).to receive(:set).with({ worker: anything }, anything)
        expect(limit_gauge_double).to receive(:set)
          .with({ worker: worker_with_concurrency_limit.name }, limit)

        worker.perform
      end
    end

    context 'when worker_name is absent' do
      subject(:perform) { worker.perform }

      context 'when worker is being limited' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .and_return(0)
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .with(worker_with_concurrency_limit.name).and_return(10000)
        end

        it 'schedules workers' do
          expect(described_class).to receive(:perform_async).with(worker_with_concurrency_limit.name)

          perform
        end
      end

      context 'when there are no jobs in the queue' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
            .and_return(10)
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .and_return(0)
        end

        it 'does not schedule workers' do
          expect(described_class).not_to receive(:perform_async)

          perform
        end
      end

      context 'when worker is not enabled to use concurrency limit middleware' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
            .and_return(0)
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .and_return(0)
        end

        it 'does not schedule workers' do
          expect(described_class).not_to receive(:perform_async)

          perform
        end
      end
    end

    context 'when worker_name is present' do
      subject(:perform) { worker.perform('ElasticCommitIndexerWorker') }

      context 'when there are no jobs in the queue' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
            .and_return(10)
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .and_return(0)
        end

        it 'does nothing' do
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
            .not_to receive(:resume_processing!)

          perform
        end

        it 'does not log worker concurrency limit stats' do
          expect(Gitlab::SidekiqLogging::ConcurrencyLimitLogger.instance).not_to receive(:worker_stats_log)

          perform
        end

        it_behaves_like 'report prometheus metrics', 10, 0
      end

      context 'when there are jobs in the queue' do
        before do
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .and_return(0)
          allow(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService).to receive(:queue_size)
            .with(worker_with_concurrency_limit.name).and_return(10000)
          stub_application_setting(elasticsearch_max_code_indexing_concurrency: 60)
        end

        it 'logs worker concurrency limit stats' do
          # note that we stub all workers limit to 0 except worker_with_concurrency_limit
          expect(Gitlab::SidekiqLogging::ConcurrencyLimitLogger.instance).to receive(:worker_stats_log).once

          perform
        end

        it 'resumes processing' do
          stub_application_setting(elasticsearch_max_code_indexing_concurrency: 35)
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
          .to receive(:resume_processing!)
          .with(worker_with_concurrency_limit.name, limit: 35 - concurrent_workers)

          perform
        end

        it 'resumes processing if there are other jobs' do
          stub_application_setting(elasticsearch_max_code_indexing_concurrency: 60)
          expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
          .to receive(:resume_processing!)
          .with(worker_with_concurrency_limit.name, limit: 60 - concurrent_workers)

          perform
        end

        it_behaves_like 'report prometheus metrics', 60

        context 'when limit is negative' do
          before do
            allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for).and_return(0)
            allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
              .with(worker: worker_with_concurrency_limit)
              .and_return(-1)
          end

          it 'does not schedule any workers' do
            expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
              .not_to receive(:resume_processing!)
            expect(described_class).not_to receive(:perform_in)

            perform
          end

          it_behaves_like 'report prometheus metrics', -1
        end

        context 'when limit is not set' do
          before do
            allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for).and_return(0)
            allow(::Gitlab::SidekiqMiddleware::ConcurrencyLimit::WorkersMap).to receive(:limit_for)
              .with(worker: worker_with_concurrency_limit)
              .and_return(0)
          end

          it 'resumes processing using the BATCH_SIZE' do
            expect(Gitlab::SidekiqMiddleware::ConcurrencyLimit::ConcurrencyLimitService)
              .to receive(:resume_processing!)
                .with(worker_with_concurrency_limit.name, limit: described_class::BATCH_SIZE)
            expect(described_class).to receive(:perform_in)

            perform
          end

          it_behaves_like 'report prometheus metrics', 0
        end
      end
    end
  end
end
