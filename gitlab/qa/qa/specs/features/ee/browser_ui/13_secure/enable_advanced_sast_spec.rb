# frozen_string_literal: true

module QA
  RSpec.describe 'Secure', :runner, product_group: :static_analysis do
    let!(:project) do
      create(:project, :with_readme,
        name: 'advanced-sast-project',
        description: 'To test Advanced SAST setup')
    end

    let!(:runner) do
      create(:project_runner,
        project: project,
        name: "runner-for-#{project.name}",
        tags: ['secure_advanced_sast'],
        executor: :docker)
    end

    let(:vulnerability_filepath) do
      'test.py:15-17'
    end

    let(:vulnerability_name) do
      'Allocation of resources without limits or throttling'
    end

    let(:scanner_name) do
      'GitLab Advanced SAST'
    end

    before do
      create(:commit,
        project: project,
        branch: project.default_branch,
        actions: [
          {
            action: 'create',
            file_path: 'test.py',
            content: File.read(
              File.join(
                EE::Runtime::Path.fixtures_path, 'secure_advanced_sast_files',
                'test-py'
              )
            )
          }
        ])
    end

    context 'when Advanced SAST is enabled' do
      it 'finds a vulnerability',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/471561' do
        create(:commit,
          project: project,
          branch: project.default_branch,
          commit_message: 'Commit .gitlab-ci.yml',
          actions: [
            {
              action: 'create',
              file_path: '.gitlab-ci.yml',
              content: File.read(
                File.join(
                  EE::Runtime::Path.fixtures_path, 'secure_advanced_sast_files',
                  '.gitlab-ci.yml'
                ))
            }
          ])

        Flow::Pipeline.wait_for_latest_pipeline_to_have_status(project: project, status: 'success')

        Flow::Login.sign_in
        project.visit_latest_pipeline
        Page::Project::Pipeline::Show.perform(&:click_on_security)

        EE::Page::Project::Secure::PipelineSecurity.perform do |pipeline_security|
          expect(pipeline_security).to have_vulnerability(vulnerability_name)

          pipeline_security.select_vulnerability(vulnerability_name)

          expect(pipeline_security).to have_modal_scanner_type(scanner_name)
          expect(pipeline_security).to have_modal_vulnerability_filepath(vulnerability_filepath)

          pipeline_security.close_modal
        end

        Page::Project::Menu.perform(&:go_to_vulnerability_report)
        EE::Page::Project::Secure::SecurityDashboard.perform do |vulnerability_report|
          expect(vulnerability_report).to have_vulnerability(description: vulnerability_name)

          vulnerability_report.click_vulnerability(description: vulnerability_name)
        end
        EE::Page::Project::Secure::VulnerabilityDetails.perform do |vulnerability_details|
          expect(vulnerability_details).to have_scanner(scanner_name)
          expect(vulnerability_details).to have_filepath(vulnerability_filepath)
        end
      end
    end
  end
end
