# frozen_string_literal: true

module QA
  RSpec.describe 'Data Stores', product_group: :global_search do
    describe(
      'When using elasticsearch API to search for a known blob',
      :orchestrated,
      :elasticsearch,
      :requires_admin,
      only: { pipeline: :nightly }
    ) do
      include Support::API
      include_context 'advanced search active'

      p1_threshold = 15
      p2_threshold = 10
      p3_threshold = 5
      p4_threshold = 3

      let(:project_file_content) { "elasticsearch: #{SecureRandom.hex(8)}" }
      let(:api_client) { Runtime::User::Store.user_api_client }
      let(:project) { create(:project, name: "api-es-#{SecureRandom.hex(8)}") }

      before do
        create(:commit, project: project, actions: [
          { action: 'create', file_path: 'README.md', content: project_file_content }
        ])
      end

      it(
        'searches public project and finds a blob as an non-member user',
        testcase: 'https://gitlab.com/gitlab-org/gitlab/-/quality/test_cases/348089'
      ) do
        start_time = Time.now
        while (Time.now - start_time) / 60 < p1_threshold
          response = Support::API.get(Runtime::Search.create_search_request(api_client, 'blobs',
            project_file_content).url)
          response_body = parse_body(response)
          expect(response.code).to eq(QA::Support::API::HTTP_STATUS_OK)

          break if !response_body.empty? &&
            response_body[0][:data].match(project_file_content) &&
            response_body[0][:project_id].equal?(project.id)

          sleep 10
        end

        time_elapsed = (Time.now - start_time) / 60
        threshold_exceeded_index = [p1_threshold, p2_threshold, p3_threshold, p4_threshold]
                                     .index { |t| time_elapsed >= t }
        if threshold_exceeded_index
          failed = threshold_exceeded_index == 0
          raise "Search #{failed ? 'failed' : 'succeeded'}. Time elapsed: #{time_elapsed} minutes. " \
            "Recommend filing P#{threshold_exceeded_index + 1} bug"
        end

        QA::Runtime::Logger.debug("Search successfully completed before #{p4_threshold} minutes.")
      end
    end
  end
end
