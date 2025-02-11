# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::Pipeline::Chain::SetBuildSources, feature_category: :security_policy_management do
  include RepoHelpers

  let(:opts) { {} }
  let_it_be(:group) { create(:group) }
  let_it_be(:project) { create(:project, :repository, group: group) }
  let_it_be(:user) { create(:user, developer_of: [project]) }

  let(:command) do
    Gitlab::Ci::Pipeline::Chain::Command.new(
      project: project,
      current_user: user,
      origin_ref: 'master'
    )
  end

  let(:pipeline) { build(:ci_pipeline, project: project) }

  subject(:perform) do
    described_class.new(pipeline, command).perform!
  end

  describe '#perform!' do
    let(:pipeline_seed) do
      pipeline_seed = instance_double(Gitlab::Ci::Pipeline::Seed::Pipeline)
      allow(pipeline_seed).to receive(:stages).and_return(
        [
          instance_double(Ci::Stage, statuses: [
            build_double(name: "build", options: {}),
            build_double(name: "namespace_policy_job", options: { execution_policy_job: true })
          ]),
          instance_double(Ci::Stage, statuses: [
            build_double(name: "rspec", options: {}),
            build_double(name: "secret-detection-0", options: {}),
            build_double(name: "project_policy_job", options: { execution_policy_job: true }),
            build_double(name: "secret-detection-1", options: { execution_policy_job: true })
          ])
        ]
      )
      pipeline_seed
    end

    before do
      allow(command).to receive(:pipeline_seed).and_return(pipeline_seed)
    end

    context 'with security policy' do
      it 'sets correct build and pipeline source for jobs' do
        expected_sources = {
          "build" => pipeline.source,
          "namespace_policy_job" => "pipeline_execution_policy",
          "rspec" => pipeline.source,
          "secret-detection-0" => "scan_execution_policy",
          "project_policy_job" => "pipeline_execution_policy",
          "secret-detection-1" => "pipeline_execution_policy"
        }

        # rubocop:disable RSpec/IteratedExpectation -- setting mock expectations individually
        pipeline_seed.stages.flat_map(&:statuses).each do |build|
          expect(build).to receive(:build_build_source).with(
            source: expected_sources[build.name],
            project_id: project.id
          )
        end
        # rubocop:enable RSpec/IteratedExpectation

        perform
      end

      context 'with feature flag disabled' do
        before do
          stub_feature_flags(populate_and_use_build_source_table: false)
        end

        it 'does not create build source records' do # -- setting mock expectations individually
          pipeline_seed.stages.flat_map(&:statuses).each do |build|
            expect(build).not_to receive(:build_build_source)
          end
          perform
        end
      end
    end
  end

  private

  def build_double(**args)
    double = instance_double(::Ci::Build, **args)
    allow(double).to receive(:instance_of?).with(::Ci::Build).and_return(true)
    double
  end
end
