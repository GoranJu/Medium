# frozen_string_literal: true

require 'spec_helper'

RSpec.describe PathLocks::UnlockService, feature_category: :source_code_management do
  let(:path_lock)    { create :path_lock }
  let(:current_user) { path_lock.user }
  let(:project)      { path_lock.project }
  let(:path)         { path_lock.path }

  describe '#execute(path_lock)' do
    subject(:execute) { described_class.new(project, current_user).execute(path_lock) }

    context 'when the user can unlock the path lock' do
      before do
        allow_next_instance_of(described_class) do |instance|
          allow(instance).to receive(:can?).with(current_user, :admin_path_locks, path_lock).and_return(true)
        end
      end

      it 'unlocks path' do
        expect { execute }.to change { project.path_locks.for_paths(path).count }.from(1).to(0)
      end

      it_behaves_like 'refreshes project.path_locks_changed_epoch value'
    end

    context 'when the user cannot unlock the path lock' do
      let(:current_user) { build(:user) }

      let(:exception) { PathLocks::UnlockService::AccessDenied }

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
