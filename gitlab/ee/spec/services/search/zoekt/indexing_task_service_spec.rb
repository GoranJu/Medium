# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::IndexingTaskService, feature_category: :global_search do
  let_it_be(:ns) { create(:group) }
  let_it_be(:project) { create(:project, :repository, namespace: ns) }
  let_it_be(:node) { create(:zoekt_node, :enough_free_space) }
  let_it_be(:zoekt_enabled_namespace) { create(:zoekt_enabled_namespace, namespace: ns) }
  let_it_be(:zoekt_index) { create(:zoekt_index, zoekt_enabled_namespace: zoekt_enabled_namespace, node: node) }

  describe '.execute' do
    let(:service) { described_class.new(project.id, :index_repo) }

    it 'executes the task' do
      expect(described_class).to receive(:new).with(project.id, :index_repo).and_return(service)
      expect(service).to receive(:execute)
      described_class.execute(project.id, :index_repo)
    end
  end

  describe '#execute' do
    RSpec.shared_examples 'creates a task when circuit breaker is disabled' do
      context 'with index circuit breaker feature flag disabled' do
        before do
          stub_feature_flags(zoekt_index_circuit_breaker: false)
        end

        it 'creates Search::Zoekt::Task record' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
        end
      end
    end

    context 'when a watermark is exceeded' do
      let(:service) { described_class.new(project.id, task_type) }
      let(:task_type) { :index_repo }

      before do
        allow(Search::Zoekt::Router).to receive(:fetch_indices_for_indexing)
          .with(project.id, root_namespace_id: zoekt_enabled_namespace.root_namespace_id)
          .and_return(zoekt_index)

        allow(zoekt_index).to receive(:find_each).and_yield(zoekt_index)
      end

      context 'on low watermark' do
        before do
          stub_feature_flags(zoekt_random_force_reindexing: false)
          allow(zoekt_index).to receive(:low_watermark_exceeded?).and_return(true)
        end

        context 'with initial indexing' do
          it 'does not create Search::Zoekt::Task record for initial indexing' do
            expect { service.execute }.not_to change { Search::Zoekt::Task.count }
          end

          it 'reschedules the indexing task worker' do
            expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_in).with(
              30.minutes, project.id, task_type, { index_id: zoekt_index.id }
            )

            service.execute
          end

          it_behaves_like 'creates a task when circuit breaker is disabled'
        end

        context 'with force reindexing' do
          let(:task_type) { :force_index_repo }

          context 'when a repo does not exist' do
            it 'does not create Search::Zoekt::Task record for initial indexing' do
              expect(service.initial_indexing?).to eq(true)
              expect { service.execute }.not_to change { Search::Zoekt::Task.count }
            end

            it 'reschedules the indexing task worker' do
              expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_in).with(
                30.minutes, project.id, task_type, { index_id: zoekt_index.id }
              )

              service.execute
            end

            it_behaves_like 'creates a task when circuit breaker is disabled'
          end

          context 'when a repo already exists' do
            let_it_be(:repo_state) { ::Search::Zoekt::Repository.states.fetch(:pending) }
            let_it_be(:zoekt_repo) do
              create(:zoekt_repository, project: project, zoekt_index: zoekt_index, state: repo_state)
            end

            it_behaves_like 'creates a task when circuit breaker is disabled'

            context 'and is ready' do
              let_it_be(:repo_state) { ::Search::Zoekt::Repository.states.fetch(:ready) }

              it 'does not create Search::Zoekt::Task record for initial indexing' do
                expect(service.initial_indexing?).to eq(true)
                expect { service.execute }.not_to change { Search::Zoekt::Task.count }
              end

              it 'reschedules the indexing task worker' do
                expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_in).with(
                  30.minutes, project.id, task_type, { index_id: zoekt_index.id }
                )

                service.execute
              end

              it_behaves_like 'creates a task when circuit breaker is disabled'
            end

            context 'and is not ready' do
              let_it_be(:repo_state) { ::Search::Zoekt::Repository.states.fetch(:orphaned) }

              it 'does not create Search::Zoekt::Task record for initial indexing' do
                expect(service.initial_indexing?).to eq(true)
                expect { service.execute }.not_to change { Search::Zoekt::Task.count }
              end

              it 'reschedules the indexing task worker' do
                expect(Search::Zoekt::IndexingTaskWorker).to receive(:perform_in).with(
                  30.minutes, project.id, task_type, { index_id: zoekt_index.id }
                )

                service.execute
              end

              it_behaves_like 'creates a task when circuit breaker is disabled'
            end
          end
        end

        context 'with incremental indexing' do
          before do
            create(:zoekt_repository, project: project, zoekt_index: zoekt_index, state: :ready)
          end

          it 'allows incremental indexing' do
            expect(service.initial_indexing?).to eq(false)
            expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
          end
        end
      end

      context 'on high watermark' do
        before do
          allow(zoekt_index).to receive(:high_watermark_exceeded?).and_return(true)
        end

        it 'does not create Search::Zoekt::Task record' do
          expect { service.execute }.not_to change { Search::Zoekt::Task.count }
        end

        it_behaves_like 'creates a task when circuit breaker is disabled'
      end
    end

    context 'when task_type is delete_repo' do
      let(:service) { described_class.new(project.id, :delete_repo) }

      it 'creates Search::Zoekt::Task record' do
        expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
      end
    end

    context 'when task_type is not delete_repo' do
      let(:task_type) { 'index_repo' }
      let(:service) { described_class.new(project.id, task_type) }

      context 'when zoekt_random_force_reindexing is disabled' do
        before do
          stub_feature_flags(zoekt_random_force_reindexing: false)
        end

        context 'for preflight_check? is false' do
          context 'if project does not have a repository' do
            let_it_be(:project) { create(:project, :empty_repo, namespace: ns) }

            it 'does not creates Search::Zoekt::Task record' do
              expect { service.execute }.not_to change { Search::Zoekt::Task.count }
            end
          end

          context 'if project does not exists' do
            it 'does not creates Search::Zoekt::Task record' do
              project.destroy!
              service = described_class.new(project.id, task_type)
              expect { service.execute }.not_to change { Search::Zoekt::Task.count }
            end
          end
        end

        context 'when Repository does not exists' do
          it 'creates a Repository record and a Task record' do
            expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
              .and change { Search::Zoekt::Repository.count }.by(1)
            repo = Search::Zoekt::Repository.find_by(project: project, zoekt_index: zoekt_index)
            expect(repo).to be_present
            new_task = repo.tasks.last
            expect(new_task.zoekt_node_id).to eq zoekt_index.zoekt_node_id
            expect(new_task).to be_pending
            expect(new_task.task_type).to eq task_type
          end
        end

        context 'when Repository already exists' do
          let_it_be(:zoekt_repo) { create(:zoekt_repository, project: project, zoekt_index: zoekt_index) }

          it 'creates only a Task record' do
            expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
              .and change { Search::Zoekt::Repository.count }.by(0)
            new_task = zoekt_repo.tasks.last
            expect(new_task.zoekt_node_id).to eq zoekt_index.zoekt_node_id
            expect(new_task).to be_pending
            expect(new_task.task_type).to eq task_type
          end
        end

        context 'when delay is passed' do
          let(:delay) { 1.hour }
          let(:service) { described_class.new(project.id, task_type, delay: delay) }

          it 'sets perform_at with delay' do
            freeze_time do
              service.execute
              new_task = Search::Zoekt::Task.last
              expect(new_task.perform_at).to eq delay.from_now
            end
          end
        end
      end

      context 'when zoekt_random_force_reindexing is enabled' do
        before do
          stub_feature_flags(zoekt_random_force_reindexing: true)
          stub_const("#{described_class}::REINDEXING_CHANCE_PERCENTAGE", 100)
        end

        it 'replaces the task type to force_index_repo' do
          expect { service.execute }.to change { Search::Zoekt::Task.count }.by(1)
            .and change { Search::Zoekt::Repository.count }.by(1)

          repo = Search::Zoekt::Repository.find_by(project: project, zoekt_index: zoekt_index)
          expect(repo.tasks.last.task_type).to eq 'force_index_repo'
        end
      end

      context 'when index is orphaned' do
        before do
          zoekt_index.orphaned!
        end

        it 'does not do anything' do
          expect { service.execute }.not_to change { Search::Zoekt::Task.count }
        end
      end

      context 'when index is pending deletion' do
        before do
          zoekt_index.pending_deletion!
        end

        it 'does not do anything' do
          expect { service.execute }.not_to change { Search::Zoekt::Task.count }
        end
      end
    end
  end
end
