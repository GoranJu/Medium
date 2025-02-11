# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Internal::Search::Zoekt, feature_category: :global_search do
  include GitlabShellHelpers
  include APIInternalBaseHelpers

  describe 'GET /internal/search/zoekt/:uuid/tasks' do
    let(:endpoint) { "/internal/search/zoekt/#{uuid}/tasks" }
    let(:uuid) { '3869fe21-36d1-4612-9676-0b783ef2dcd7' }
    let(:valid_params) do
      {
        'uuid' => uuid,
        'node.url' => 'http://localhost:6090',
        'node.name' => 'm1.local',
        'disk.all' => 994662584320,
        'disk.free' => 461988872192,
        'disk.indexed' => 2416879,
        'disk.used' => 532673712128
      }
    end

    context 'with invalid auth' do
      it 'returns 401' do
        get api(endpoint),
          params: valid_params,
          headers: gitlab_shell_internal_api_request_header(issuer: 'gitlab-workhorse')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with valid auth' do
      subject(:request) { get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header }

      let(:node) { build(:zoekt_node) }

      before do
        allow(::Search::Zoekt::Node).to receive(:find_or_initialize_by_task_request)
                                           .with(valid_params).and_return(node)
      end

      context 'with feature flag disabled' do
        before do
          stub_feature_flags(zoekt_internal_api_register_nodes: false)
        end

        context 'when node does not exist' do
          let(:node) { build(:zoekt_node, id: nil) }

          it 'does not save node' do
            expect(node).not_to receive(:save)

            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq(
              { 'id' => nil, 'tasks' => [], 'pull_frequency' => Search::Zoekt::Node::TASK_PULL_FREQUENCY_DEFAULT,
                'truncate' => true, 'stop_indexing' => false, 'optimized_performance' => true }
            )
          end
        end

        context 'when node exists' do
          let(:node) { create(:zoekt_node, id: 123) }

          it 'does not save node when node does not exist' do
            expect(node).not_to receive(:save)

            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq(
              { 'id' => node.id, 'tasks' => [], 'pull_frequency' => Search::Zoekt::Node::TASK_PULL_FREQUENCY_DEFAULT,
                'truncate' => false, 'stop_indexing' => false, 'optimized_performance' => true }
            )
          end
        end
      end

      context 'when a task request is received with valid params' do
        let(:node) { build(:zoekt_node, id: 123) }
        let(:tasks) { %w[task1 task2] }

        before do
          allow(::Search::Zoekt::TaskPresenterService).to receive(:execute).and_return(tasks)
        end

        it 'returns node ID and tasks for task request' do
          expect(node).to receive(:save).and_return(true)

          get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq(
            { 'id' => node.id, 'tasks' => tasks, 'pull_frequency' => Search::Zoekt::Node::TASK_PULL_FREQUENCY_DEFAULT,
              'truncate' => true, 'stop_indexing' => false, 'optimized_performance' => true }
          )
        end

        context 'when zoekt_reduced_pull_frequency is disabled' do
          before do
            stub_feature_flags(zoekt_reduced_pull_frequency: false)
          end

          it 'does not adds pull_frequency in the response' do
            expect(node).to receive(:save).and_return(true)

            get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header

            expect(::Search::Zoekt::TaskPresenterService).not_to receive(:execute)
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'id' => node.id, 'tasks' => tasks, 'truncate' => true,
                                          'pull_frequency' =>  Search::Zoekt::Node::TASK_PULL_FREQUENCY_DEFAULT,
                                          'stop_indexing' => false, 'optimized_performance' => true })
          end
        end

        context 'when zoekt_optimized_performance_indexing is disabled' do
          before do
            stub_feature_flags(zoekt_optimized_performance_indexing: false)
          end

          it 'sends optimized_performance as false' do
            expect(node).to receive(:save).and_return(true)

            get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header

            expect(::Search::Zoekt::TaskPresenterService).not_to receive(:execute)
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to eq({ 'id' => node.id, 'tasks' => tasks, 'truncate' => true,
                                          'pull_frequency' =>  Search::Zoekt::Node::TASK_PULL_FREQUENCY_DEFAULT,
                                          'optimized_performance' => false, 'stop_indexing' => false })
          end
        end

        context 'when node is over critical watermark' do
          before do
            allow(::Search::Zoekt::TaskPresenterService).to receive(:execute).with(node).and_return([])
            allow(node).to receive_messages(save_debouce: true, watermark_exceeded_critical?: true)
          end

          it 'sets stop_indexing attribute in response to true' do
            get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header
            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response).to include('stop_indexing' => true)
          end

          context 'when zoekt_critical_watermark_stop_indexing is disabled' do
            before do
              stub_feature_flags(zoekt_critical_watermark_stop_indexing: false)
            end

            it 'does not add stop_indexing in the response' do
              get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header
              expect(response).to have_gitlab_http_status(:ok)
              expect(json_response).not_to have_key('stop_indexing')
            end
          end
        end
      end

      context 'when a heartbeat has valid params but a node validation error occurs' do
        let(:node) { build(:zoekt_node, id: 123, search_base_url: nil) }

        it 'returns 422' do
          get api(endpoint), params: valid_params, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when a heartbeat is received with invalid params' do
        it 'returns 400' do
          get api(endpoint), params: { 'foo' => 'bar' }, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end

  describe 'POST /internal/search/zoekt/:uuid/callback' do
    let_it_be(:project) { create(:project) }
    let(:endpoint) { "/internal/search/zoekt/#{uuid}/callback" }
    let(:uuid) { ::Search::Zoekt::Node.last.uuid }
    let(:logger) { instance_double(::Search::Zoekt::Logger) }
    let(:params) do
      {
        name: 'index',
        success: true,
        payload: { key: 'value' }
      }
    end

    before do
      zoekt_ensure_namespace_indexed!(project.root_namespace)
    end

    context 'with invalid auth' do
      it 'returns 401' do
        post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header(issuer: 'dummy-workhorse')

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'with valid auth' do
      let(:log_data) do
        {
          class: described_class, callback_name: params[:name], payload: params[:payload], additional_payload: nil,
          success: true, error_message: nil, action: :callback
        }
      end

      context 'when node is found' do
        before do
          allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
        end

        context 'and parms success is true' do
          it 'logs the info and returns accepted' do
            node = Search::Zoekt::Node.find_by_uuid(uuid)
            log_data[:meta] = node.metadata_json
            expect(logger).to receive(:info).with(log_data.as_json)
            expect(::Search::Zoekt::CallbackService).to receive(:execute).with(node, params)
            post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header
            expect(response).to have_gitlab_http_status(:accepted)
          end
        end

        context 'and params success is false' do
          it 'logs the error and returns accepted' do
            params.merge!({ success: false, error: 'Message' })
            node = Search::Zoekt::Node.find_by_uuid(uuid)
            log_data_with_meta = log_data.merge(
              {
                success: false, error_message: 'Message',
                meta: node.metadata_json
              }
            )
            expect(logger).to receive(:error).with(log_data_with_meta.as_json)
            expect(::Search::Zoekt::CallbackService).to receive(:execute).with(node, params)
            post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header
            expect(response).to have_gitlab_http_status(:accepted)
          end
        end

        context 'when additional_payload sent in the params' do
          let(:additional_payload) do
            { repo_stats: { index_file_count: 1, size_in_bytes: 1 } }
          end

          it 'log the additional_payload attributes' do
            params[:additional_payload] = additional_payload
            node = Search::Zoekt::Node.find_by_uuid(uuid)
            log_data_with_meta = log_data.merge(
              {
                additional_payload: additional_payload,
                meta: node.metadata_json
              }
            )
            expect(logger).to receive(:info).with(log_data_with_meta.as_json)
            expect(::Search::Zoekt::CallbackService).to receive(:execute).with(node, params)
            post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header, as: :json
            expect(response).to have_gitlab_http_status(:accepted)
          end
        end
      end

      context 'when node is not found' do
        let(:uuid) { 'non_existing' }

        it 'logs the info and returns unprocessable_entity!' do
          allow(::Search::Zoekt::Logger).to receive(:build).and_return(logger)
          expect(logger).to receive(:info).with(log_data.as_json)
          expect(::Search::Zoekt::CallbackService).not_to receive(:execute)
          post api(endpoint), params: params, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:unprocessable_entity)
        end
      end

      context 'when a request is received with invalid params' do
        it 'returns bad_request' do
          expect(::Search::Zoekt::CallbackService).not_to receive(:execute)
          post api(endpoint), params: { 'foo' => 'bar' }, headers: gitlab_shell_internal_api_request_header
          expect(response).to have_gitlab_http_status(:bad_request)
        end
      end
    end
  end
end
