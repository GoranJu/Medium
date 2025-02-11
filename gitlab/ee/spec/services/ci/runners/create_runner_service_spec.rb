# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::Ci::Runners::CreateRunnerService, '#execute', feature_category: :runner do
  let_it_be(:admin) { create(:admin) }
  let_it_be(:group_owner) { create(:user) }
  let_it_be(:group) { create(:group, owners: group_owner) }
  let_it_be(:project) { create(:project, namespace: group) }

  let(:runner) { execute.payload[:runner] }
  let(:expected_audit_kwargs) do
    {
      name: 'ci_runner_created',
      message: 'Created %{runner_type} CI runner'
    }
  end

  subject(:execute) { described_class.new(user: current_user, params: params).execute }

  RSpec::Matchers.define :last_ci_runner do
    match { |runner| runner == ::Ci::Runner.last }
  end

  shared_examples 'a service logging a runner audit event' do
    it 'returns newly-created runner' do
      expect_next_instance_of(
        ::AuditEvents::RunnerAuditEventService,
        last_ci_runner, current_user, expected_token_scope, **expected_audit_kwargs
      ) do |service|
        expect(service).to receive(:track_event).once.and_call_original
      end

      expect(execute).to be_success
      expect(runner).to eq(::Ci::Runner.last)
    end
  end

  context 'with :runner_type param set to instance_type' do
    let(:current_user) { admin }
    let(:params) { { runner_type: 'instance_type' } }
    let(:expected_token_scope) { an_instance_of(Gitlab::Audit::InstanceScope) }

    it 'runner payload is nil' do
      expect(runner).to be_nil
    end

    it { is_expected.to be_error }

    context 'when admin mode is enabled', :enable_admin_mode do
      it_behaves_like 'a service logging a runner audit event'
    end
  end

  context 'with :runner_type param set to group_type' do
    let(:current_user) { group_owner }
    let(:params) { { runner_type: 'group_type', scope: group } }
    let(:expected_token_scope) { group }

    it_behaves_like 'a service logging a runner audit event'
  end

  context 'with :runner_type param set to project_type' do
    let(:current_user) { group_owner }
    let(:params) { { runner_type: 'project_type', scope: project } }
    let(:expected_token_scope) { project }

    it_behaves_like 'a service logging a runner audit event'
  end
end
