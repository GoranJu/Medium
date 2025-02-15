# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Container-Scanning.gitlab-ci.yml', feature_category: :continuous_integration do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('Container-Scanning') }

  describe 'the created pipeline' do
    let_it_be_with_refind(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }

    let(:default_branch) { 'master' }
    let(:user) { project.first_owner }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: 'master') }
    let(:pipeline) { service.execute(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }

    before do
      stub_ci_pipeline_yaml_file(template.content)
      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    context 'when project has no license' do
      context 'when branch pipeline' do
        it 'includes job' do
          expect(build_names).to match_array(%w[container_scanning])
        end
      end

      context 'with CS_MAJOR_VERSION greater than 3' do
        before do
          create(:ci_variable, project: project, key: 'CS_MAJOR_VERSION', value: '4')
        end

        it 'includes job' do
          expect(build_names).to match_array(%w[container_scanning])
        end
      end

      context 'when CONTAINER_SCANNING_DISABLED=1' do
        before do
          create(:ci_variable, project: project, key: 'CONTAINER_SCANNING_DISABLED', value: '1')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end
    end
  end
end
