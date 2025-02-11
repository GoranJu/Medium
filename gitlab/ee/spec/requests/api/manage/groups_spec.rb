# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::Manage::Groups, feature_category: :system_access do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:group) { create(:group) }
  let_it_be(:current_user_token) { create(:personal_access_token, user: current_user, scopes: [:api]) }

  before_all do
    group.add_owner(current_user)
  end

  shared_examples 'response as expected' do |params|
    subject(:get_request) { get api(path, personal_access_token: current_user_token), params: params }

    it "status, count and result as expected" do
      get_request

      case status
      when :bad_request
        expect(json_response).to eq(result)
      when :ok
        expect(map_id(json_response)).to a_collection_containing_exactly(*result)
      end

      expect(response).to have_gitlab_http_status(status)
      expect(json_response.count).to eq(result_count)
    end
  end

  shared_examples 'paginated data for enterprise users' do
    it 'returns paginated success response' do
      get api(path, personal_access_token: current_user_token)

      expect(response).to have_gitlab_http_status(:ok)
      expect_paginated_array_response_contain_exactly(user_token.id)
      expect(json_response).to be_an_instance_of(Array)
      expect(json_response.first).to include('id', 'name', 'scopes', 'expires_at')
    end
  end

  describe 'GET /groups/:id/manage/personal_access_tokens' do
    using RSpec::Parameterized::TableSyntax

    let_it_be(:user) { create(:enterprise_user, enterprise_group: group) }
    let_it_be(:user_token) { create(:personal_access_token, user: user, scopes: [:api]) }
    let_it_be(:path) { "/groups/#{group.id}/manage/personal_access_tokens" }

    context "when feature flag is disabled" do
      before do
        stub_feature_flags(manage_pat_by_group_owners_ready: false)
      end

      it 'returns 404 not found' do
        get api(path, personal_access_token: current_user_token)

        expect(response).to have_gitlab_http_status(:not_found)
      end
    end

    context 'when group has non enterprise users as well' do
      let_it_be(:non_enterprise_user) { create(:user) }

      before_all do
        group.add_reporter(user)
        create(:personal_access_token, user: non_enterprise_user, scopes: [:api])
      end

      it_behaves_like 'paginated data for enterprise users'

      it "does not return data for non enterprise users" do
        get api(path, personal_access_token: current_user_token)

        expect(map_id(json_response)).not_to include(non_enterprise_user.id)
      end
    end

    it_behaves_like 'paginated data for enterprise users'

    it 'returns 404 for non-existing group' do
      get api("/groups/non-existing/manage/personal_access_tokens", personal_access_token: current_user_token)

      expect(response).to have_gitlab_http_status(:not_found)
    end

    it 'returns 403 for unauthorized user' do
      unauthorized_user = create(:user)
      token = create(:personal_access_token, user: unauthorized_user, scopes: [:api])

      get api(path, personal_access_token: token)

      expect(response).to have_gitlab_http_status(:forbidden)
    end

    context 'when filter with active parameter' do
      let_it_be(:inactive_token1) { create(:personal_access_token, user: user, revoked: true) }
      let_it_be(:inactive_token2) do
        create(:personal_access_token, user: user, expires_at: 1.year.ago)
      end

      let_it_be(:active_token) { create(:personal_access_token, user: user, scopes: [:api]) }

      where(:state, :status, :result_count, :result) do
        'inactive' | "200 OK" | 2 | lazy { [inactive_token1.id, inactive_token2.id] }
        'active'   | "200 OK" | 2 | lazy { [active_token.id, user_token.id] }
        'asdf'     | "400 Bad Request" | 1 | { "error" => "state does not have a valid value" }
      end

      with_them do
        it_behaves_like 'response as expected', state: params[:state]
      end
    end

    context 'when filter with revoked parameter' do
      let_it_be(:revoked_token) { create(:personal_access_token, user: user, revoked: true) }
      let_it_be(:not_revoked_token1) { create(:personal_access_token, user: user, revoked: false) }
      let_it_be(:not_revoked_token2) { create(:personal_access_token, user: user, revoked: false) }

      where(:revoked, :status, :result_count, :result) do
        true   | :ok          | 1 | lazy { [revoked_token.id] }
        false  | :ok          | 3 | lazy { [not_revoked_token1.id, not_revoked_token2.id, user_token.id] }
        'asdf' | :bad_request | 1 | { "error" => "revoked is invalid" }
      end

      with_them do
        it_behaves_like 'response as expected', revoked: params[:revoked]
      end
    end

    context 'when filter with created parameter' do
      let_it_be(:token1) do
        create(:personal_access_token, user: user, created_at: DateTime.new(2022, 1, 1, 12, 30, 25))
      end

      context 'when created_before is passed' do
        where(:created_at, :status, :result_count, :result) do
          '2022-01-02'           | :ok          | 1 | lazy { [token1.id] }
          '2022-01-01'           | :ok          | 0 | lazy { [] }
          '2022-01-01T12:30:24'  | :ok          | 0 | lazy { [] }
          '2022-01-01T12:30:25'  | :ok          | 1 | lazy { [token1.id] }
          '2022-01-01T:12:30:26' | :ok          | 1 | lazy { [token1.id] }
          'asdf'                 | :bad_request | 1 | { "error" => "created_before is invalid" }
        end

        with_them do
          it_behaves_like 'response as expected', created_before: params[:created_at]
        end
      end

      context 'when filter with created_after' do
        where(:created_at, :status, :result_count, :result) do
          '2022-01-03'            | :ok          | 1 | lazy { [user_token.id] }
          '2022-01-01'            | :ok          | 2 | lazy { [token1.id, user_token.id] }
          '2022-01-01T12:30:25'   | :ok          | 2 | lazy { [token1.id, user_token.id] }
          '2022-01-01T12:30:26'   | :ok          | 1 | lazy { [user_token.id] }
          (DateTime.now + 1).to_s | :ok          | 0 | lazy { [] }
          'asdf'                  | :bad_request | 1 | { "error" => "created_after is invalid" }
        end

        with_them do
          it_behaves_like 'response as expected', created_after: params[:created_at]
        end
      end
    end

    context 'when last_used is passed' do
      let_it_be(:token1) do
        create(:personal_access_token, user: user, last_used_at: DateTime.new(2022, 1, 1, 12, 30, 25))
      end

      let_it_be(:never_used_token) { create(:personal_access_token, user: user) }

      context 'when last_used_before is passed' do
        where(:last_used_at, :status, :result_count, :result) do
          '2022-01-02'          | :ok          | 1 | lazy { [token1.id] }
          '2022-01-01'          | :ok          | 0 | lazy { [] }
          '2022-01-01T12:30:24' | :ok          | 0 | lazy { [] }
          '2022-01-01T12:30:25' | :ok          | 1 | lazy { [token1.id] }
          '2022-01-01T12:30:26' | :ok          | 1 | lazy { [token1.id] }
          'asdf'                | :bad_request | 1 | { "error" => "last_used_before is invalid" }
        end

        with_them do
          it_behaves_like 'response as expected', last_used_before: params[:last_used_at]
        end
      end

      context 'when last_used_after is passed' do
        where(:last_used_at, :status, :result_count, :result) do
          '2022-01-03'            | :ok          | 0 | lazy { [] }
          '2022-01-01'            | :ok          | 1 | lazy { [token1.id] }
          '2022-01-01T12:30:26'   | :ok          | 0 | lazy { [] }
          '2022-01-01T12:30:25'   | :ok          | 1 | lazy { [token1.id] }
          (DateTime.now + 1).to_s | :ok          | 0 | lazy { [] }
          'asdf'                  | :bad_request | 1 | { "error" => "last_used_after is invalid" }
        end

        with_them do
          it_behaves_like 'response as expected', last_used_after: params[:last_used_at]
        end
      end
    end

    context 'when filter with search parameter' do
      let_it_be(:token1) { create(:personal_access_token, user: user,  name: 'test_1') }
      let_it_be(:token2) { create(:personal_access_token, user: user,  name: 'test_2') }

      where(:pattern, :status, :result_count, :result) do
        'test'   | :ok | 2 | lazy { [token1.id, token2.id] }
        ''       | :ok | 3 | lazy { [token1.id, token2.id, user_token.id] }
        'test_1' | :ok | 1 | lazy { [token1.id] }
        'asdf'   | :ok | 0 | lazy { [] }
      end

      with_them do
        it_behaves_like 'response as expected', search: params[:pattern]
      end
    end

    context 'when filter created_before/created_after combined with last_used_before/last_used_after' do
      let_it_be(:date) { DateTime.new(2022, 1, 2) }
      let_it_be(:token1) { create(:personal_access_token, created_at: date, user: user, last_used_at: date) }

      before do
        user_token.update!(last_used_at: DateTime.now)
      end

      where(:date_before, :date_after, :status, :result_count, :result) do
        '2022-01-03' | '2022-01-01' | :ok | 1 | lazy { [token1.id] }
        '2022-01-01' | '2022-01-03' | :ok | 0 | lazy { [] }
        '2022-01-03' | nil          | :ok | 1 | lazy { [token1.id] }
        nil          | '2022-01-01' | :ok | 2 | lazy { [token1.id, user_token.id] }
      end

      with_them do
        it_behaves_like 'response as expected', { created_before: params[:date_before],
                                                  created_after: params[:date_after] }
        it_behaves_like 'response as expected', { last_used_before: params[:date_before],
                                                  last_used_after: params[:date_after] }
      end
    end

    context 'when filter created_before and created_after combined is valid' do
      let_it_be(:token1) { create(:personal_access_token, user: user, created_at: DateTime.new(2022, 1, 2)) }

      where(:created_before, :created_after, :status, :result) do
        '2022-01-02' | '2022-01-02' | :ok | lazy { [token1.id] }
        '2022-01-03' | '2022-01-01' | :ok | lazy { [token1.id] }
        '2022-01-01' | '2022-01-03' | :ok | lazy { [] }
        '2022-01-03' | nil          | :ok | lazy { [token1.id] }
        nil          | '2022-01-01' | :ok | lazy { [token1.id] }
      end

      with_them do
        it "returns all valid tokens" do
          get api(path, personal_access_token: current_user_token),
            params: { created_before: created_before, created_after: created_after }

          expect(response).to have_gitlab_http_status(status)

          expect(json_response.pluck('id')).to include(*result) if status == :ok && !result.empty?
        end
      end
    end

    context 'when filter last_used_before and last_used_after combined is valid' do
      let_it_be(:token1) { create(:personal_access_token, user: user, last_used_at: DateTime.new(2022, 1, 2)) }

      where(:last_used_before, :last_used_after, :status, :result) do
        '2022-01-02' | '2022-01-02' | :ok | lazy { [token1.id] }
        '2022-01-03' | '2022-01-01' | :ok | lazy { [token1.id] }
        '2022-01-01' | '2022-01-03' | :ok | lazy { [] }
        '2022-01-03' | nil          | :ok | lazy { [token1.id] }
        nil          | '2022-01-01' | :ok | lazy { [token1.id] }
      end

      with_them do
        it "returns all valid tokens" do
          get api(path, personal_access_token: current_user_token),
            params: { last_used_before: last_used_before, last_used_after: last_used_after }

          expect(response).to have_gitlab_http_status(status)

          expect(json_response.pluck('id')).to include(*result) if status == :ok && !result.empty?
        end
      end
    end
  end

  def map_id(_json_resonse)
    json_response.pluck('id')
  end
end
