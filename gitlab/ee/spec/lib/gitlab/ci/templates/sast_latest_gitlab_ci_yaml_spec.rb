# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'SAST.latest.gitlab-ci.yml', feature_category: :continuous_integration do
  include Ci::PipelineMessageHelpers

  subject(:template) do
    <<~YAML
      include:
        - template: 'Jobs/SAST.latest.gitlab-ci.yml'
    YAML
  end

  describe 'the created pipeline' do
    let(:default_branch) { 'master' }
    let(:files) { { 'README.txt' => '' } }
    let(:project) { create(:project, :custom_repo, files: files) }
    let(:user) { project.first_owner }
    let(:service) { Ci::CreatePipelineService.new(project, user, ref: 'master') }
    let(:pipeline) { service.execute(:push).payload }
    let(:build_names) { pipeline.builds.pluck(:name) }

    before do
      stub_ci_pipeline_yaml_file(template)
      allow_next_instance_of(Ci::BuildScheduleWorker) do |worker|
        allow(worker).to receive(:perform).and_return(true)
      end
      allow(project).to receive(:default_branch).and_return(default_branch)
    end

    context 'when project has no license' do
      let(:files) { { 'a.rb' => '' } }

      context 'when SAST_DISABLED="1"' do
        before do
          create(:ci_variable, project: project, key: 'SAST_DISABLED', value: '1')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end

      context 'when SAST_DISABLED="true"' do
        before do
          create(:ci_variable, project: project, key: 'SAST_DISABLED', value: 'true')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end

      context 'when SAST_DISABLED="false"' do
        before do
          create(:ci_variable, project: project, key: 'SAST_DISABLED', value: 'false')
        end

        it 'includes jobs' do
          expect(build_names).not_to be_empty
        end
      end

      context 'when SAST_EXPERIMENTAL_FEATURES is disabled for iOS projects' do
        let(:files) { { 'a.xcodeproj/x.pbxproj' => '' } }

        before do
          create(:ci_variable, project: project, key: 'SAST_EXPERIMENTAL_FEATURES', value: 'false')
        end

        it 'includes no jobs' do
          expect(build_names).to be_empty
          expect(pipeline.errors.full_messages).to match_array([sanitize_message(Ci::Pipeline.rules_failure_message)])
        end
      end

      context 'by default' do
        it "doesn't include gitlab-advanced-sast" do
          expect(build_names).not_to include('gitlab-advanced-sast')
        end

        describe 'language detection' do
          let(:kubernetes_vars) { { 'SCAN_KUBERNETES_MANIFESTS' => 'true' } }

          using RSpec::Parameterized::TableSyntax

          where(:case_name, :files, :variables, :jobs) do
            'Apex'                 | { 'app.cls' => '' }                             | {}                      | %w[pmd-apex-sast]
            'C'                    | { 'app.c' => '' }                               | {}                      | %w[semgrep-sast]
            'C++'                  | { 'app.cpp' => '' }                             | {}                      | %w[semgrep-sast]
            'C#'                   | { 'app.cs' => '' }                              | {}                      | %w[semgrep-sast]
            'Elixir'               | { 'mix.exs' => '' }                             | {}                      | %w[sobelow-sast]
            'Elixir, nested'       | { 'a/b/mix.exs' => '' }                         | {}                      | %w[sobelow-sast]
            'Golang'               | { 'main.go' => '' }                             | {}                      | %w[semgrep-sast]
            'Groovy'               | { 'app.groovy' => '' }                          | {}                      | %w[spotbugs-sast]
            'Java'                 | { 'app.java' => '' }                            | {}                      | %w[semgrep-sast]
            'Javascript'           | { 'app.js' => '' }                              | {}                      | %w[semgrep-sast]
            'JSX'                  | { 'app.jsx' => '' }                             | {}                      | %w[semgrep-sast]
            'Kotlin'               | { 'app.kt' => '' }                              | {}                      | %w[semgrep-sast]
            'Kubernetes Manifests' | { 'Chart.yaml' => '' }                          | ref(:kubernetes_vars)   | %w[kubesec-sast]
            'Multiple languages'   | { 'app.java' => '', 'app.js' => '' }            | {}                      | %w[semgrep-sast]
            'Objective C'          | { 'app.m' => '' }                               | {}                      | %w[semgrep-sast]
            'PHP'                  | { 'app.php' => '' }                             | {}                      | %w[semgrep-sast]
            'Python'               | { 'app.py' => '' }                              | {}                      | %w[semgrep-sast]
            'Ruby'                 | { 'config/routes.rb' => '' }                    | {}                      | %w[semgrep-sast]
            'Scala'                | { 'app.scala' => '' }                           | {}                      | %w[semgrep-sast]
            'Scala'                | { 'app.sc' => '' }                              | {}                      | %w[semgrep-sast]
            'Swift'                | { 'app.swift' => '' }                           | {}                      | %w[semgrep-sast]
            'Typescript'           | { 'app.ts' => '' }                              | {}                      | %w[semgrep-sast]
            'Typescript JSX'       | { 'app.tsx' => '' }                             | {}                      | %w[semgrep-sast]
          end

          with_them do
            before do
              variables.each do |(key, value)|
                create(:ci_variable, project: project, key: key, value: value)
              end
            end

            it_behaves_like 'acts as branch pipeline', params[:jobs]

            it_behaves_like 'acts as MR pipeline', params[:jobs], params[:files]
          end
        end
      end
    end

    context 'when project has Ultimate license' do
      let(:license) { build(:license, plan: License::ULTIMATE_PLAN) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      describe 'language detection' do
        using RSpec::Parameterized::TableSyntax

        where(:case_name, :files, :variables, :jobs) do
          'Golang with advanced SAST'                         | { 'main.go' => '' }                          | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'Java with advanced SAST'                           | { 'app.java' => '' }                         | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'JSP with advanced SAST'                            | { 'app.jsp' => '' }                          | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'Javascript with advanced SAST'                     | { 'app.js' => '' }                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'C# with advanced SAST'                             | { 'app.cs' => '' }                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'Python with advanced SAST'                         | { 'app.py' => '' }                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'Ruby with advanced SAST'                           | { 'config/routes.rb' => '' }                 | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'Python and Ruby with advanced SAST'                | { 'app.py' => '', 'config/routes.rb' => '' } | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast]
          'Python and Objective C with advanced SAST'         | { 'app.py' => '', 'app.m' => '' }            | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' }                                                 | %w[gitlab-advanced-sast semgrep-sast]
          'Golang without advanced SAST'                      | { 'main.go' => '' }                          | {}                                                                                           | %w[semgrep-sast]
          'Golang with disabled advanced SAST'                | { 'main.go' => '' }                          | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[semgrep-sast]
          'Java with disabled advanced SAST'                  | { 'app.java' => '' }                         | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[semgrep-sast]
          'JSP with disabled advanced SAST'                   | { 'app.jsp' => '' }                          | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[]
          'Python with disabled advanced SAST'                | { 'app.py' => '' }                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[semgrep-sast]
          'Ruby with disabled advanced SAST'                  | { 'config/routes.rb' => '' }                 | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[semgrep-sast]
          'Javascript with disabled advanced SAST'            | { 'app.js' => '' }                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[semgrep-sast]
          'C# with disabled advanced SAST'                    | { 'app.cs' => '' }                           | { 'GITLAB_ADVANCED_SAST_ENABLED' => 'false' }                                                | %w[semgrep-sast]
          'Python with Static Reachability'                   | { 'app.py' => '' }                           | { 'GITLAB_STATIC_REACHABILITY_ENABLED' => 'true' }                                           | %w[gitlab-static-reachability gitlab-enrich-cdx-results semgrep-sast]
          'Python with Static Reachability and advanced SAST' | { 'app.py' => '' }                           | { 'GITLAB_STATIC_REACHABILITY_ENABLED' => 'true', 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' } | %w[gitlab-static-reachability gitlab-enrich-cdx-results gitlab-advanced-sast]
          'Java with Static Reachability'                     | { 'app.java' => '' }                         | { 'GITLAB_STATIC_REACHABILITY_ENABLED' => 'true' }                                           | %w[gitlab-static-reachability gitlab-enrich-cdx-results semgrep-sast]
          'Java with Static Reachability and advanced SAST'   | { 'app.java' => '' }                         | { 'GITLAB_STATIC_REACHABILITY_ENABLED' => 'true', 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' } | %w[gitlab-static-reachability gitlab-enrich-cdx-results gitlab-advanced-sast]
          'JSP with Static Reachability'                      | { 'app.jsp' => '' }                          | { 'GITLAB_STATIC_REACHABILITY_ENABLED' => 'true' }                                           | %w[gitlab-static-reachability gitlab-enrich-cdx-results]
          'JSP with Static Reachability and advanced SAST'    | { 'app.jsp' => '' }                          | { 'GITLAB_STATIC_REACHABILITY_ENABLED' => 'true', 'GITLAB_ADVANCED_SAST_ENABLED' => 'true' } | %w[gitlab-static-reachability gitlab-enrich-cdx-results gitlab-advanced-sast]
        end

        with_them do
          before do
            variables.each do |(key, value)|
              create(:ci_variable, project: project, key: key, value: value)
            end
          end

          it_behaves_like 'acts as branch pipeline', params[:jobs]

          it_behaves_like 'acts as MR pipeline', params[:jobs], params[:files]

          it 'excludes already-covered extensions when both gitlab-advanced-sast and semgrep-sast run' do
            gitlab_advanced_sast_extensions = %w[.py .go .java .js .jsx .ts .tsx .cjs .mjs .cs]

            if build_names.include?('gitlab-advanced-sast') && build_names.include?('semgrep-sast')
              # expect the variable SAST_EXCLUDED_PATHS of semgrep-sast to contain the list of extensions supported by gitlab-advanced-sast
              variables = pipeline.builds.find_by(name: 'semgrep-sast').variables
              sast_excluded_paths = variables.find { |v| v.key == 'SAST_EXCLUDED_PATHS' }.value
              gitlab_advanced_sast_extensions.each do |ext|
                expect(sast_excluded_paths).to include("**/*#{ext}")
              end
            end
          end
        end
      end
    end
  end
end
