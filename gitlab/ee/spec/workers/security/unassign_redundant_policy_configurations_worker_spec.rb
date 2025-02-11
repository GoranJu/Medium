# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::UnassignRedundantPolicyConfigurationsWorker, :sidekiq_inline, feature_category: :security_policy_management do
  describe '#perform' do
    let_it_be(:user) { create(:user) }

    let_it_be(:top_level_group) { create(:group) }
    let_it_be(:subgroup_a) { create(:group, parent: top_level_group) }
    let_it_be(:subgroup_b) { create(:group, parent: subgroup_a) }

    let_it_be(:project) { create(:project, group: subgroup_a) }

    let!(:policy_configuration_a) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: top_level_group.id)
    end

    let!(:policy_configuration_b) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: subgroup_b.id,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:policy_configuration_c) do
      create(
        :security_orchestration_policy_configuration,
        project: project,
        security_policy_management_project_id: policy_project_id)
    end

    let!(:other_policy_configuration) do
      create(
        :security_orchestration_policy_configuration,
        :namespace,
        namespace_id: subgroup_a.id)
    end

    let(:policy_project_id) { policy_configuration_a.security_policy_management_project_id }
    let_it_be(:security_policy_bot) { create(:user, :security_policy_bot) }

    subject(:execute) { described_class.new.perform(top_level_group.id, policy_project_id, user.id) }

    before_all do
      create(:project_member, user: security_policy_bot, project: project)
    end

    it 'does not unassign top-level group' do
      expect { execute }.not_to change {
        Security::OrchestrationPolicyConfiguration.exists?(policy_configuration_a.id)
      }.from(true)
    end

    it 'unassigns projects and groups with redundant policy projects' do
      execute

      [policy_configuration_b, policy_configuration_c].each do |config|
        expect(Security::OrchestrationPolicyConfiguration.exists?(config.id)).to be(false)
      end
    end

    it 'does not unassign unrelated projects' do
      expect { execute }.not_to change {
        Security::OrchestrationPolicyConfiguration.exists?(other_policy_configuration.id)
      }.from(true)
    end

    it 'keeps bot users' do
      expect { execute }.not_to change { project.security_policy_bot }.from(security_policy_bot)
    end
  end

  describe 'deduplication' do
    let(:group_id) { 1 }
    let(:policy_project_id) { 2 }
    let(:user_id_a) { 3 }
    let(:user_id_b) { 4 }

    let(:job_a) { { 'class' => described_class.name, 'args' => [group_id, policy_project_id, user_id_a] } }
    let(:job_b) { { 'class' => described_class.name, 'args' => [group_id, policy_project_id, user_id_b] } }

    let(:duplicate_job_a) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_a, 'test') }
    let(:duplicate_job_b) { Gitlab::SidekiqMiddleware::DuplicateJobs::DuplicateJob.new(job_b, 'test') }

    specify do
      expect(duplicate_job_a.send(:idempotency_key) == duplicate_job_b.send(:idempotency_key)).to be(true)
    end
  end
end
