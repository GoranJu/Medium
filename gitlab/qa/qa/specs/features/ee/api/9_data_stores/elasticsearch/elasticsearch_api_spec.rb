# frozen_string_literal: true

module QA
  RSpec.describe 'Data Stores', product_group: :global_search do
    describe(
      'When using elasticsearch API to search for a known blob',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:project_file_content) { "elasticsearch: #{SecureRandom.hex(8)}" }
      let(:non_member_user) { create(:user, :with_personal_access_token) }
      let(:non_member_api_client) { non_member_user.api_client }
      let(:api_client) { Runtime::User::Store.user_api_client }

      let(:project) { create(:project, name: "api-es-#{SecureRandom.hex(8)}") }

      before do
        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'README.md', content: project_file_content }
        ])
      end

      it(
        'searches public project and finds a blob as an non-member user',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348063'
      ) do
        successful_search(non_member_api_client)
      end

      describe 'When searching a private repository' do
        before do
          project.set_visibility(:private)
        end

        it(
          'finds a blob as an authorized user',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348064'
        ) do
          successful_search(api_client)
        end

        it(
          'does not find a blob as an non-member user',
          testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348065'
        ) do
          QA::Support::Retrier.retry_on_exception(
            max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
            sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
          ) do
            response = Support::API.get(Runtime::Search.create_search_request(non_member_api_client, 'blobs',
              project_file_content).url)
            response_body = parse_body(response)

            aggregate_failures do
              expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
              expect(response_body).to be_empty
            end
          end
        end
      end

      private

      def successful_search(api_client)
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'blobs',
            project_file_content).url)
          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
          response_body = parse_body(response)

          aggregate_failures do
            expect(response_body).not_to be_empty
            expect(response_body[0][:data]).to match(project_file_content)
            expect(response_body[0][:project_id]).to equal(project.id)
          end
        end
      end
    end
  end
end
