# frozen_string_literal: true

module QA
  RSpec.describe 'Data Stores', product_group: :global_search do
    describe(
      'When using elasticsearch API to search for a public issue',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      except: :production
    ) do
      include Support::API
      include_context 'advanced search active'

      let(:api_client) { Runtime::User::Store.user_api_client }

      let(:issue) do
        create(:issue,
          title: 'Issue for issue index test',
          description: "Some issue description #{SecureRandom.hex(8)}")
      end

      it(
        'finds issue that matches description',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/347635'
      ) do
        QA::Support::Retrier.retry_on_exception(
          max_attempts: Runtime::Search::RETRY_MAX_ITERATION,
          sleep_interval: Runtime::Search::RETRY_SLEEP_INTERVAL
        ) do
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'issues',
            issue.description).url)
          response_body = parse_body(response)

          aggregate_failures do
            expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)
            expect(response_body).not_to be_empty
            expect(response_body[0][:description]).to eq(issue.description)
            expect(response_body[0][:project_id]).to equal(issue.project.id)
          end
        end
      end
    end
  end
end
