# frozen_string_literal: true

require 'spec_helper'

RSpec.shared_examples 'includes no jobs' do
  it 'includes no jobs' do
    expect(build_names).to be_empty
    expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
  end
end

RSpec.describe 'DAST.latest.gitlab-ci.yml', feature_category: :continuous_integration do
  include Ci::PipelineMessageHelpers

  subject(:template) { Gitlab::Template::GitlabCiYmlTemplate.find('DAST.latest') }

  describe 'the created pipeline' do
    let(:default_branch) { project.default_branch_or_main }
    let(:pipeline_branch) { default_branch }
    let(:project) { create(:project, :custom_repo, files: { 'README.txt' => '' }) }
    let(:user) { project.first_owner }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: pipeline_branch) }
    let(:pipeline) { service.execute(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }
    let(:ci_pipeline_yaml) { "stages: [\"dast\"]\n" }

    specify { expect(template).not_to be_nil }

    context 'when ci yaml is just template' do
      before do
        stub_ci_pipeline_yaml_file(template.content)

        allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
          allow(worker).to receive(:perform).and_return(true)
        end

        allow(project).to receive(:default_branch).and_return(default_branch)
      end

      context 'when project has no license' do
        it 'includes no jobs' do
          expect(build_names).to be_empty
        end
      end
    end

    context 'when stages includes dast' do
      before do
        stub_ci_pipeline_yaml_file(ci_pipeline_yaml + template.content)

        allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
          allow(worker).to receive(:perform).and_return(true)
        end

        allow(project).to receive(:default_branch).and_return(default_branch)
      end

      context 'when project has no license' do
        include_examples 'includes no jobs'
      end

      context 'when project has cluster' do
        before do
          create(:cluster, :project, :provided_by_gcp, projects: [project])
        end

        context 'by default' do
          include_examples 'includes no jobs'
        end

        context 'when project has Ultimate license' do
          let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

          before do
            allow(License).to receive(:current).and_return(license)
          end

          context 'when no specification provided' do
            it_behaves_like 'acts as branch pipeline', %w[dast]
          end
        end
      end

      context 'by default' do
        include_examples 'includes no jobs'
      end

      context 'when project has Ultimate license' do
        let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

        before do
          allow(License).to receive(:current).and_return(license)
        end

        context 'when project has cluster' do
          before do
            create(:cluster, :project, :provided_by_gcp, projects: [project])
          end

          context 'when DAST_DISABLED=1' do
            before do
              create(:ci_variable, project: project, key: 'DAST_DISABLED', value: '1')
            end

            include_examples 'includes no jobs'
          end

          context 'when DAST_DISABLED="true"' do
            before do
              create(:ci_variable, project: project, key: 'DAST_DISABLED', value: 'true')
            end

            include_examples 'includes no jobs'
          end

          context 'when DAST_DISABLED="false"' do
            before do
              create(:ci_variable, project: project, key: 'DAST_DISABLED', value: 'false')
            end

            it 'includes jobs' do
              expect(build_names).not_to be_empty
            end
          end

          context 'when CI_GITLAB_FIPS_MODE unset' do
            let(:build_dast) { pipeline.builds.find_by(name: 'dast') }
            let(:build_variables) { build_dast.variables.pluck(:key, :value) }

            it 'sets DAST_IMAGE_SUFFIX to ""' do
              expect(build_variables).to be_include(['DAST_IMAGE_SUFFIX', ''])
            end
          end

          context 'when CI_GITLAB_FIPS_MODE=true' do
            let(:build_dast) { pipeline.builds.find_by(name: 'dast') }
            let(:build_variables) { build_dast.variables.pluck(:key, :value) }

            before do
              create(:ci_variable, project: project, key: 'CI_GITLAB_FIPS_MODE', value: 'true')
            end

            it 'sets DAST_IMAGE_SUFFIX to "-fips"' do
              expect(build_variables).to be_include(['DAST_IMAGE_SUFFIX', '-fips'])
            end
          end

          context 'when DAST_DISABLED_FOR_DEFAULT_BRANCH=1' do
            before do
              create(:ci_variable, project: project, key: 'DAST_DISABLED_FOR_DEFAULT_BRANCH', value: '1')
            end

            context 'when on default branch' do
              include_examples 'includes no jobs'
            end

            context 'when on feature branch' do
              let(:pipeline_branch) { 'patch-1' }

              before do
                project.repository.create_branch(pipeline_branch, default_branch)
              end

              it 'includes dast job' do
                expect(build_names).to match_array(%w[dast])
              end
            end

            it_behaves_like 'acts as MR pipeline', %w[dast], { 'CHANGELOG.md' => '' }
          end

          context 'when DAST_DISABLED_FOR_DEFAULT_BRANCH="false"' do
            before do
              create(:ci_variable, project: project, key: 'DAST_DISABLED_FOR_DEFAULT_BRANCH', value: 'false')
            end

            context 'when on default branch' do
              it 'includes dast job' do
                expect(build_names).to match_array(%w[dast])
              end
            end

            context 'when on feature branch' do
              let(:pipeline_branch) { 'patch-1' }

              before do
                project.repository.create_branch(pipeline_branch, default_branch)
              end

              it 'includes dast job' do
                expect(build_names).to match_array(%w[dast])
              end
            end

            it_behaves_like 'acts as MR pipeline', %w[dast], { 'CHANGELOG.md' => '' }
          end

          context 'when REVIEW_DISABLED="true"' do
            before do
              create(:ci_variable, project: project, key: 'REVIEW_DISABLED', value: 'true')
            end

            context 'when on default branch' do
              it_behaves_like 'acts as branch pipeline', %w[dast]
            end

            context 'when on feature branch' do
              let(:pipeline_branch) { 'patch-1' }

              before do
                project.repository.create_branch(pipeline_branch, default_branch)
              end

              include_examples 'includes no jobs'
            end
          end

          context 'when REVIEW_DISABLED="false"' do
            before do
              create(:ci_variable, project: project, key: 'REVIEW_DISABLED', value: 'false')
            end

            context 'when on default branch' do
              it_behaves_like 'acts as branch pipeline', %w[dast]
            end

            context 'when on feature branch' do
              let(:pipeline_branch) { 'patch-1' }

              before do
                project.repository.create_branch(pipeline_branch, default_branch)
              end

              it 'includes dast job' do
                expect(build_names).to match_array(%w[dast])
              end
            end
          end
        end
      end
    end
  end
end
