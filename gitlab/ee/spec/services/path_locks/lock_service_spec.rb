# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PathLocks::LockService, feature_category: :source_code_management do
  let(:current_user) { create(:user) }
  let(:project)      { create(:project) }
  let(:path)         { 'app/models' }

  describe '#execute(path)' do
    subject(:execute) { described_class.new(project, current_user).execute(path) }

    context 'when user can push code' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:can?).with(current_user, :push_code, project).and_return(true)
        end
      end

      it 'locks path' do
        expect { execute }.to change { project.path_locks.for_paths(path).count }.from(0).to(1)
      end

      it_behaves_like 'refreshes project.path_locks_changed_epoch value'
    end

    context 'when user cannot push code' do
      let(:exception) { PathLocks::LockService::AccessDenied }

      it 'raises exception if user has no permissions' do
        expect { execute }.to raise_exception(exception)
      end

      context 'when the exception has been handled' do
        subject do
          execute
        rescue exception
        end

        it_behaves_like 'does not refresh project.path_locks_changed_epoch'
      end
    end
  end
end
