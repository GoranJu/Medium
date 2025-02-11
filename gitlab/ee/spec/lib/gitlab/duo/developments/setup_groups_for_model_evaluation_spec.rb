# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::SetupGroupsForModelEvaluation, :saas, :gitlab_duo, :silence_stdout, feature_category: :duo_chat do
  let_it_be(:user) { create(:user, username: 'root') }
  let(:group) { create(:group) }
  let(:setup_evaluation) { described_class.new(group) }
  let(:http_response) { instance_double(HTTParty::Response) }
  let(:file_double) { instance_double(File) }

  before do
    allow(SecureRandom).to receive(:hex).and_return('1')
  end

  describe '#execute' do
    context 'when the server is running' do
      before do
        allow(http_response).to receive(:success?).and_return(true)
        allow(http_response).to receive(:parsed_response).and_return({ 'id' => 1 })
        allow(Gitlab::HTTP).to receive(:get).and_return(http_response)
        allow(Gitlab::HTTP).to receive(:get).with("https://gitlab.com/gitlab-org/ai-powered/datasets/-/package_files/135727282/download")
          .and_return(http_response)
      end

      it 'goes through the process' do
        expect(setup_evaluation).to receive(:set_token!)
        expect(setup_evaluation).to receive(:ensure_server_running!)
        expect(setup_evaluation).to receive(:ensure_instance_setting!)
        expect(setup_evaluation).to receive(:download_and_unpack_file)
        expect(setup_evaluation).to receive(:create_subgroups)
        expect(setup_evaluation).to receive(:create_subprojects)
        expect(setup_evaluation).to receive(:check_import_status)
        expect(setup_evaluation).to receive(:delete_temporary_directory!)
        expect(setup_evaluation).to receive(:clean_up_token!)
        expect(setup_evaluation).to receive(:print_output)

        setup_evaluation.execute
      end

      describe '#set_token!' do
        it 'creates token' do
          expect { setup_evaluation.send(:set_token!) }.to change { PersonalAccessToken.count }.by(1)
        end
      end

      describe '#clean_up_token!' do
        it 'deletes token' do
          setup_evaluation.send(:set_token!)

          expect { setup_evaluation.send(:clean_up_token!) }.to change { PersonalAccessToken.count }.by(-1)
        end
      end

      describe '#ensure_instance_setting!' do
        it 'sets Gitlab::CurrentSettings import_sources' do
          setup_evaluation.send(:ensure_instance_setting!)

          expect(Gitlab::CurrentSettings.import_sources.include?('gitlab_project')).to be_truthy
        end
      end

      describe '#download_and_unpack_file' do
        it 'unzips the file' do
          expect(setup_evaluation).to receive(:unzip_file).with('tmp', 'duo_chat_samples.tar.gz')

          setup_evaluation.send(:download_and_unpack_file)
        end

        it 'runs through files' do
          expect(FileUtils).to receive(:rm)

          setup_evaluation.send(:download_and_unpack_file)
        end
      end

      describe '#delete_temporary_directory!' do
        it 'deletes folder' do
          expect(FileUtils).to receive(:rm_rf).at_least(:once)

          setup_evaluation.send(:delete_temporary_directory!)
        end
      end

      describe '#create_subgroups' do
        it 'creates subgroups' do
          expect(setup_evaluation).to receive(:create_subgroup).with(name: 'gitlab-com',
            file: Rails.root.join("tmp/duo_chat_samples/gitlab_com/01_group.tar.gz"))
          expect(setup_evaluation).to receive(:create_subgroup).with(name: 'gitlab-org',
            file: Rails.root.join("tmp/duo_chat_samples/gitlab_org/01_group.tar.gz"))

          setup_evaluation.send(:create_subgroups)
        end
      end

      describe '#create_subprojects' do
        it 'creates subprojects' do
          gitlab_com_group = create(:group, name: 'gitlab-com', parent: group)
          gitlab_org_group = create(:group, name: 'gitlab-org', parent: group)

          expect(setup_evaluation).to receive(:create_subproject).with(
            name: 'www-gitlab-com',
            file: Rails.root.join("tmp/duo_chat_samples/gitlab_com/02_www_gitlab_com.tar.gz"),
            namespace_id: gitlab_com_group.id
          )
          expect(setup_evaluation).to receive(:create_subproject).with(
            name: 'gitlab',
            file: Rails.root.join("tmp/duo_chat_samples/gitlab_org/02_gitlab.tar.gz"),
            namespace_id: gitlab_org_group.id
          )

          setup_evaluation.send(:create_subprojects)
        end
      end

      describe '#create_subgroup' do
        it 'creates a subgroup' do
          file = Rails.root.join("tmp/duo_chat_samples/gitlab_com/01_group.tar.gz")
          body = { name: 'gitlab-com', path: 'gitlab-com',
                   parent_id: group.id, file: file_double, organization_id: group.organization_id }

          expect(File).to receive(:new).with(file).and_return(file_double)
          expect(setup_evaluation).to receive(:token_value).and_return('token-string-1')

          expect(Gitlab::HTTP).to receive(:post)
                                    .with("#{setup_evaluation.send(:instance_url)}/api/v4/groups/import",
                                      headers: { 'PRIVATE-TOKEN' => 'token-string-1' }, body: hash_including(**body))
                                    .and_return(http_response)

          setup_evaluation.send(:create_subgroup, name: 'gitlab-com', file: file)
        end
      end

      describe '#create_subproject' do
        it 'creates a subproject' do
          gitlab_com_group = create(:group, name: 'gitlab-com', parent: group)

          file = Rails.root.join("tmp/duo_chat_samples/gitlab_com/02_www_gitlab_com.tar.gz")
          body = { name: 'www-gitlab-com', path: 'www-gitlab-com', namespace: gitlab_com_group.id, file: file_double }

          expect(File).to receive(:new).with(file).and_return(file_double)
          expect(setup_evaluation).to receive(:token_value).and_return('token-string-1')

          expect(Gitlab::HTTP).to receive(:post)
                                    .with("#{setup_evaluation.send(:instance_url)}/api/v4/projects/import",
                                      body: hash_including(**body), headers: { 'PRIVATE-TOKEN' => 'token-string-1' })
                                    .and_return(http_response)

          setup_evaluation.send(:create_subproject, name: 'www-gitlab-com', file: file,
            namespace_id: gitlab_com_group.id)
        end
      end

      describe '#check_import_status' do
        before do
          allow(http_response).to receive(:parsed_response).and_return({ 'import_status' => 'finished' })
          allow(setup_evaluation).to receive(:token_value).and_return('token-string-1')
        end

        it 'checks import status for projects' do
          setup_evaluation.instance_variable_set(:@project_ids, [1])

          expect(Gitlab::HTTP).to receive(:get)
                                    .with("#{setup_evaluation.send(:instance_url)}/api/v4/projects/1/import",
                                      headers: { 'PRIVATE-TOKEN' => 'token-string-1' })
                                    .and_return(http_response)

          setup_evaluation.send(:check_import_status)
          expect(setup_evaluation.send(:errors)).to be_empty
        end

        context 'with import not finished' do
          before do
            allow(http_response).to receive(:parsed_response).and_return({ 'import_status' => 'scheduled' },
              { 'import_status' => 'finished' })
            allow(http_response).to receive(:success?).and_return(true).twice
          end

          it 'waits for the import to finish' do
            setup_evaluation.instance_variable_set(:@project_ids, [1])

            expect(Gitlab::HTTP).to receive(:get)
                                      .with("#{setup_evaluation.send(:instance_url)}/api/v4/projects/1/import",
                                        headers: { 'PRIVATE-TOKEN' => 'token-string-1' })
                                      .and_return(http_response)

            expect(setup_evaluation).to receive(:sleep).with(5).twice
            setup_evaluation.send(:check_import_status)
            expect(setup_evaluation.send(:errors)).to be_empty
          end
        end

        context 'when time limit is exceeded' do
          before do
            stub_const("#{described_class}::TIME_LIMIT", 1)
            allow(http_response).to receive(:parsed_response).and_return({ 'import_status' => 'scheduled' })
            allow(http_response).to receive(:success?).and_return(true)
          end

          it 'waits for the import to finish' do
            setup_evaluation.instance_variable_set(:@project_ids, [1])

            expect(Gitlab::HTTP).to receive(:get)
                                      .with("#{setup_evaluation.send(:instance_url)}/api/v4/projects/1/import",
                                        headers: { 'PRIVATE-TOKEN' => 'token-string-1' })
                                      .and_return(http_response)

            setup_evaluation.send(:check_import_status)
            expect(setup_evaluation.send(:errors)).to include(time_limit: 'exceeded')
          end
        end
      end

      context 'when running not in dev or test mode' do
        before do
          stub_env('RAILS_ENV', 'production')
          allow(Gitlab).to receive(:dev_or_test_env?).and_return(false)
        end

        it 'raises an error' do
          expect { setup_evaluation.execute }.to raise_error(RuntimeError)
        end
      end

      context 'when finished working' do
        it 'shows a message' do
          expect do
            setup_evaluation.send(:print_output)
          end.to output(a_string_including('Setup for evaluation Performed!')).to_stdout
        end

        context 'when there are errors' do
          it 'shows a message' do
            setup_evaluation.instance_variable_set(:@errors, [{ group: 'gitlab-com' }, { project: 'www-gitlab-com' }])
            expect do
              setup_evaluation.send(:print_output)
            end.to output(a_string_including('The import has finished with errors for those resources')).to_stdout
          end
        end
      end
    end

    context 'when the server is not running' do
      before do
        allow(http_response).to receive(:success?).and_return(false)
        allow(Gitlab::HTTP).to receive(:get).and_return(http_response)
      end

      it 'raises an error' do
        expect { setup_evaluation.execute }.to raise_error('Server is not running, please start your GitLab server')
      end
    end
  end
end
