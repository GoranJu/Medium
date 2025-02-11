# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::PipelineExecutionPolicies::RunScheduleWorker, '#perform', feature_category: :security_policy_management do
  include RepoHelpers

  let_it_be(:project) { create(:project, :repository) }
  let_it_be(:ci_config_project) { create(:project, :repository) }
  let_it_be(:security_bot) { create(:user, :security_policy_bot) }
  let_it_be(:policy_ci_filename) { "policy-ci.yml" }

  let_it_be(:security_policy) do
    create(
      :security_policy,
      :pipeline_execution_schedule_policy,
      content: {
        content: { include: [{ project: ci_config_project.full_path, file: policy_ci_filename }] },
        schedule: { cadence: '0 0 * * *' }
      })
  end

  let_it_be(:schedule) do
    create(:security_pipeline_execution_project_schedule, project: project, security_policy: security_policy)
  end

  let_it_be(:ci_config) do
    {
      "scheduled_pep_job_pre" => {
        "stage" => ".pipeline-policy-pre",
        "script" => "exit 0"
      },
      "scheduled_pep_job_post" => {
        "stage" => ".pipeline-policy-post",
        "script" => "exit 0"
      },
      "scheduled_pep_job_test" => {
        "stage" => "test",
        "script" => "exit 0"
      }
    }
  end

  let_it_be(:ci_skip_commit_message) { "[ci skip] foobar" }

  let(:spp_repository_pipeline_access?) { true }
  let(:spp_linked?) { true }

  before_all do
    project.add_guest(security_bot)

    create_file_in_repo(
      ci_config_project,
      ci_config_project.default_branch_or_main,
      ci_config_project.default_branch_or_main,
      policy_ci_filename,
      ci_config.to_yaml)

    create_file_in_repo(
      project,
      project.default_branch_or_main,
      project.default_branch_or_main,
      "TEST.md",
      "",
      commit_message: ci_skip_commit_message)
  end

  before do
    ci_config_project.reload.project_setting.update!(spp_repository_pipeline_access: spp_repository_pipeline_access?)

    if spp_linked?
      create(
        :security_orchestration_policy_configuration,
        project: project,
        security_policy_management_project: ci_config_project)
    end
  end

  subject(:perform) { described_class.new.perform(schedule_id) }

  context 'when schedule exists' do
    let(:schedule_id) { schedule.id }

    it 'creates a pipeline' do
      expect { perform }.to change { project.all_pipelines.count }.from(0).to(1)
    end

    describe 'resulting pipeline' do
      subject(:pipeline) { perform.then { project.all_pipelines.last! } }

      it { is_expected.to be_created }

      it "ignores [ci skip]" do
        expect(pipeline.commit.message).to eq(ci_skip_commit_message)
      end

      it "targets the default branch" do
        expect(pipeline.ref).to eq(project.default_branch_or_main)
      end

      it "belongs to policy bot" do
        expect(pipeline.user).to eq(security_bot)
      end

      it "has expected source" do
        expect(pipeline.source).to eq("pipeline_execution_policy_schedule")
      end

      it "contains stages" do
        expect(pipeline.stages.map(&:name)).to match_array(%w[.pipeline-policy-pre test .pipeline-policy-post])
      end

      it "contains builds" do
        expect(pipeline.builds.map(&:name)).to match_array(%w[scheduled_pep_job_pre scheduled_pep_job_test
          scheduled_pep_job_post])
      end
    end

    it "doesn't log" do
      expect(Gitlab::AppJsonLogger).not_to receive(:error)

      perform
    end

    context 'when pipeline creation fails' do
      let_it_be(:expected_log) do
        {
          "class" => described_class.name,
          "event" => described_class::EVENT_KEY,
          "message" => a_string_including("Project `#{ci_config_project.full_path}` not found or access denied"),
          "reason" => nil,
          "project_id" => schedule.project_id,
          "schedule_id" => schedule.id,
          "policy_id" => schedule.security_policy.id
        }
      end

      shared_examples 'logs the error' do
        specify do
          expect(Gitlab::AppJsonLogger).to receive(:error).with(expected_log)

          perform
        end
      end

      context 'with SPP access setting disabled' do
        let(:spp_repository_pipeline_access?) { false }

        it_behaves_like 'logs the error'
      end

      context 'with SPP not linked' do
        let(:spp_linked?) { false }

        it_behaves_like 'logs the error'
      end
    end

    context 'with feature disabled' do
      before do
        stub_feature_flags(scheduled_pipeline_execution_policies: false)
      end

      it 'does not create a pipeline' do
        expect { perform }.not_to change { project.all_pipelines.count }.from(0)
      end
    end
  end

  context 'when schedule does not exist' do
    let(:schedule_id) { non_existing_record_id }

    it 'does not create a pipeline' do
      expect { perform }.not_to change { project.all_pipelines.count }.from(0)
    end
  end
end
