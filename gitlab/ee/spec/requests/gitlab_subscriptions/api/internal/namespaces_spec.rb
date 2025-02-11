# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::API::Internal::Namespaces, :saas, :aggregate_failures, :api, feature_category: :plan_provisioning do
  include AfterNextHelpers
  include GitlabSubscriptions::InternalApiHelpers

  def namespace_path(namespace_id)
    internal_api("namespaces/#{namespace_id}")
  end

  describe 'GET /internal/gitlab_subscriptions/namespaces/:id' do
    let_it_be(:namespace) { create(:group) }

    context 'when unauthenticated' do
      it 'returns an error response' do
        get namespace_path(namespace.id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          get namespace_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when fetching a group namespace' do
        it 'successfully returns the namespace attributes' do
          get namespace_path(namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to eq({
            'id' => namespace.id,
            'kind' => 'group',
            'name' => namespace.name,
            'parent_id' => nil,
            'path' => namespace.path,
            'full_path' => namespace.full_path,
            'avatar_url' => nil,
            'plan' => 'free',
            'projects_count' => 0,
            'root_repository_size' => nil,
            'shared_runners_minutes_limit' => nil,
            'trial' => false,
            'trial_ends_on' => nil,
            'web_url' => namespace.web_url,
            'additional_purchased_storage_size' => 0,
            'additional_purchased_storage_ends_on' => nil,
            'billable_members_count' => 0,
            'extra_shared_runners_minutes_limit' => nil,
            'members_count_with_descendants' => 0
          })
        end
      end

      context 'when fetching a user namespace' do
        it 'successfully returns the namespace attributes' do
          user_namespace = create(:user, :with_namespace).namespace

          get namespace_path(user_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response).to match(
            'id' => user_namespace.id,
            'kind' => 'user',
            'name' => user_namespace.name,
            'parent_id' => nil,
            'path' => user_namespace.path,
            'full_path' => user_namespace.full_path,
            'avatar_url' => user_namespace.avatar_url,
            'plan' => 'free',
            'shared_runners_minutes_limit' => nil,
            'trial' => false,
            'trial_ends_on' => nil,
            'web_url' => a_string_including(user_namespace.path),
            'additional_purchased_storage_size' => 0,
            'additional_purchased_storage_ends_on' => nil,
            'billable_members_count' => 1,
            'extra_shared_runners_minutes_limit' => nil
          )
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with an admin personal access token' do
      let_it_be(:admin) { create(:admin) }

      def namespace_path(namespace_id)
        "/internal/gitlab_subscriptions/namespaces/#{namespace_id}"
      end

      context 'when the user is not an admin' do
        it 'returns an error response' do
          user = create(:user)

          get api(namespace_path(namespace.id), user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the admin is not in admin mode' do
        it 'returns an error response' do
          get api(namespace_path(namespace.id), admin, admin_mode: false)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          get api(namespace_path(non_existing_record_id), admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when the namespace is of a group' do
        it 'returns OK status and contains some set of keys' do
          get api(namespace_path(namespace.id), admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).to contain_exactly('id', 'kind', 'name', 'path', 'full_path',
            'parent_id', 'members_count_with_descendants',
            'plan', 'shared_runners_minutes_limit',
            'avatar_url', 'web_url', 'trial_ends_on', 'trial',
            'extra_shared_runners_minutes_limit', 'billable_members_count',
            'root_repository_size', 'projects_count',
            'additional_purchased_storage_size', 'additional_purchased_storage_ends_on')
        end
      end

      context 'when the namespace is of a user' do
        it 'returns OK status and contains some set of keys' do
          user = create(:user, :with_namespace)

          get api(namespace_path(user.namespace.id), admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response.keys).to contain_exactly('id', 'kind', 'name', 'path', 'full_path',
            'parent_id', 'plan', 'shared_runners_minutes_limit',
            'avatar_url', 'web_url', 'trial_ends_on', 'trial',
            'extra_shared_runners_minutes_limit', 'billable_members_count',
            'additional_purchased_storage_size', 'additional_purchased_storage_ends_on')
        end
      end
    end
  end

  describe 'PUT /internal/gitlab_subscriptions/namespaces/:id' do
    context 'when unauthenticated' do
      it 'returns an error response' do
        put namespace_path(non_existing_record_id)

        expect(response).to have_gitlab_http_status(:unauthorized)
      end
    end

    context 'when authenticated as the subscription portal' do
      before do
        stub_internal_api_authentication
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          put namespace_path(non_existing_record_id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when a project namespace ID is passed' do
        it 'returns 404' do
          project = create(:project)

          put namespace_path(project.project_namespace.id), headers: internal_api_headers

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when updating gitlab subscription data' do
        let_it_be(:root_namespace) { create(:namespace_with_plan) }

        it "updates the gitlab_subscription record" do
          existing_subscription = root_namespace.gitlab_subscription

          params = {
            gitlab_subscription_attributes: {
              start_date: '2019-06-01',
              end_date: '2020-06-01',
              plan_code: 'ultimate',
              seats: 20,
              max_seats_used: 10,
              auto_renew: true,
              trial: true,
              trial_starts_on: '2019-05-01',
              trial_ends_on: '2019-06-01',
              trial_extension_type: GitlabSubscription.trial_extension_types[:reactivated]
            }
          }

          put namespace_path(root_namespace.id), headers: internal_api_headers, params: params

          expect(root_namespace.reload.gitlab_subscription.reload.seats).to eq 20
          expect(root_namespace.gitlab_subscription).to eq existing_subscription
        end

        it 'returns a 400 error with invalid data' do
          params = {
            gitlab_subscription_attributes: {
              start_date: nil,
              end_date: '2020-06-01',
              plan_code: 'ultimate',
              seats: nil,
              max_seats_used: 10,
              auto_renew: true
            }
          }

          put namespace_path(root_namespace.id), headers: internal_api_headers, params: params

          expect(response).to have_gitlab_http_status(:bad_request)
          expect(json_response['message']).to eq(
            "gitlab_subscription.seats" => ["can't be blank"],
            "gitlab_subscription.start_date" => ["can't be blank"]
          )
        end
      end

      describe 'runners minutes limits' do
        let_it_be(:root_namespace) do
          create(
            :group,
            :with_ci_minutes,
            ci_minutes_used: 1600,
            shared_runners_minutes_limit: 1000,
            extra_shared_runners_minutes_limit: 500
          )
        end

        context 'when updating the extra_shared_runners_minutes_limit' do
          let(:params) { { extra_shared_runners_minutes_limit: 1000 } }

          it 'updates the extra shared runners minutes limit' do
            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['extra_shared_runners_minutes_limit'])
              .to eq(params[:extra_shared_runners_minutes_limit])
          end

          it 'expires the compute minutes CachedQuota' do
            expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end

          it 'resets the current compute minutes notification level' do
            usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: root_namespace.id)
            usage.update!(notification_level: 30)

            expect { put namespace_path(root_namespace.id), headers: internal_api_headers, params: params }
              .to change { usage.reload.notification_level }
              .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
          end

          it 'refreshes cached data' do
            expect(::Ci::Minutes::RefreshCachedDataService)
              .to receive(:new)
              .with(root_namespace)
              .and_call_original

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end
        end

        context 'when updating the shared_runners_minutes_limit' do
          let(:params) { { shared_runners_minutes_limit: 9000 } }

          it 'expires the compute minutes CachedQuota' do
            expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end

          it 'resets the current compute minutes notification level' do
            usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: root_namespace.id)
            usage.update!(notification_level: 30)

            expect do
              put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
            end.to change { usage.reload.notification_level }
               .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
          end
        end

        context 'when neither minutes_limit params is provided' do
          let(:params) { { plan_code: 'free' } }

          it 'does not expire the compute minutes CachedQuota' do
            expect(Gitlab::Ci::Minutes::CachedQuota).not_to receive(:new)

            put namespace_path(root_namespace.id), headers: internal_api_headers, params: params
          end

          it 'does not reset the current compute minutes notification level' do
            usage = ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: root_namespace.id)
            usage.update!(notification_level: 30)

            expect { put namespace_path(root_namespace.id), headers: internal_api_headers, params: params }
              .not_to change { usage.reload.notification_level }
          end
        end
      end
    end

    # this method of authentication is deprecated and will be removed in
    # https://gitlab.com/gitlab-org/gitlab/-/issues/473625
    context 'when authenticating with an admin personal access token' do
      let_it_be(:admin) { create(:admin) }
      let(:user) { create(:user) }

      let(:group1) { create(:group, :with_ci_minutes, ci_minutes_used: 1600) }
      let_it_be(:group2) { create(:group, :nested) }
      let_it_be(:ultimate_plan) { create(:ultimate_plan) }
      let_it_be(:project) { create(:project, namespace: group2, name: group2.name, path: group2.path) }
      let_it_be(:project_namespace) { project.project_namespace }

      let(:usage) do
        ::Ci::Minutes::NamespaceMonthlyUsage.current_month.find_by(namespace_id: group1)
      end

      let(:params) do
        {
          shared_runners_minutes_limit: 9001,
          additional_purchased_storage_size: 10_000,
          additional_purchased_storage_ends_on: Date.today.to_s
        }
      end

      before do
        usage.update!(notification_level: 30)
        group1.update!(shared_runners_minutes_limit: 1000, extra_shared_runners_minutes_limit: 500)
      end

      def namespace_path(namespace_id)
        "/internal/gitlab_subscriptions/namespaces/#{namespace_id}"
      end

      context 'when the user is not an admin' do
        it 'returns an error response' do
          user = create(:user)

          put api(namespace_path(group1.id), user)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the admin is not in admin mode' do
        it 'returns an error response' do
          put api(namespace_path(group1.id), admin, admin_mode: false)

          expect(response).to have_gitlab_http_status(:forbidden)
        end
      end

      context 'when the namespace cannot be found' do
        it 'returns an error response' do
          put api(namespace_path(non_existing_record_id), admin, admin_mode: true)

          expect(response).to have_gitlab_http_status(:not_found)
        end
      end

      context 'when authenticated as admin' do
        subject(:request) do
          put api(namespace_path(group1.id), admin, admin_mode: true), params: params
        end

        let(:group1) { create(:group, :with_ci_minutes, ci_minutes_used: 1600, name: 'Hello.World') }

        it 'updates namespace using full_path when full_path contains dots' do
          put api(namespace_path(group1.full_path), admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['shared_runners_minutes_limit']).to eq(params[:shared_runners_minutes_limit])
          expect(json_response['additional_purchased_storage_size']).to eq(params[:additional_purchased_storage_size])
          expect(
            json_response['additional_purchased_storage_ends_on']
          ).to eq(params[:additional_purchased_storage_ends_on])
        end

        it 'updates namespace using id' do
          request

          expect(response).to have_gitlab_http_status(:ok)
          expect(json_response['shared_runners_minutes_limit']).to eq(params[:shared_runners_minutes_limit])
          expect(json_response['additional_purchased_storage_size']).to eq(params[:additional_purchased_storage_size])
          expect(
            json_response['additional_purchased_storage_ends_on']
          ).to eq(params[:additional_purchased_storage_ends_on])
        end

        it 'expires the compute minutes CachedQuota' do
          expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

          request
        end

        context 'when current compute minutes notification level is set' do
          it 'resets the current compute minutes notification level' do
            expect do
              request
            end.to change { usage.reload.notification_level }
               .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
          end
        end

        shared_examples 'handles monthly usage' do
          it 'expires the compute minutes CachedQuota' do
            expect_next(Gitlab::Ci::Minutes::CachedQuota).to receive(:expire!)

            request
          end

          it 'resets the current compute minutes notification level' do
            expect do
              request
            end.to change { usage.reload.notification_level }
              .to(Ci::Minutes::Notification::PERCENTAGES.fetch(:not_set))
          end
        end

        context 'when request has extra_shared_runners_minutes_limit param' do
          before do
            params[:extra_shared_runners_minutes_limit] = 1000
            params.delete(:shared_runners_minutes_limit)
          end

          it 'updates the extra shared runners minutes limit' do
            request

            expect(response).to have_gitlab_http_status(:ok)
            expect(json_response['extra_shared_runners_minutes_limit'])
              .to eq(params[:extra_shared_runners_minutes_limit])
          end

          it 'updates pending builds data since adding extra minutes the quota is not used up anymore' do
            minutes_exceeded = group1.ci_minutes_usage.minutes_used_up?
            expect(minutes_exceeded).to eq(true)

            pending_build = create(:ci_pending_build, namespace: group1, minutes_exceeded: minutes_exceeded)

            request

            expect(pending_build.reload.minutes_exceeded).to eq(false)
          end

          it_behaves_like 'handles monthly usage'
        end

        context 'when shared_runners_minutes_limit param is present' do
          before do
            params[:shared_runners_minutes_limit] = nil
          end

          it_behaves_like 'handles monthly usage'
        end

        context 'when neither minutes limit params is provided' do
          it 'does not expire the compute minutes CachedQuota' do
            params.delete(:shared_runners_minutes_limit)
            expect(Gitlab::Ci::Minutes::CachedQuota).not_to receive(:new)

            request
          end

          context 'when current compute minutes notification level is set' do
            it 'does not reset the current compute minutes notification level' do
              params.delete(:shared_runners_minutes_limit)

              expect { put api(namespace_path(group1.id), admin), params: params }
                .not_to change { usage.reload.notification_level }
            end
          end
        end
      end

      context 'when project namespace is passed' do
        it 'returns 404' do
          put api(namespace_path(project_namespace.id), admin, admin_mode: true), params: params

          expect(response).to have_gitlab_http_status(:not_found)
          expect(json_response).to eq('message' => '404 Namespace Not Found')
        end
      end

      context 'when invalid params' do
        where(:attr) do
          [
            :shared_runners_minutes_limit,
            :additional_purchased_storage_size,
            :additional_purchased_storage_ends_on
          ]
        end

        with_them do
          it "returns validation error for #{attr}" do
            put api(namespace_path(group1.id), admin, admin_mode: true), params: Hash[attr, 'unknown']

            expect(response).to have_gitlab_http_status(:bad_request)
          end
        end
      end

      [:last_ci_minutes_notification_at, :last_ci_minutes_usage_notification_level].each do |attr|
        context "when namespace has a value for #{attr}" do
          before do
            group1.update_attribute(attr, Time.now)
          end

          it 'resets that value when assigning extra compute minutes' do
            expect do
              put api(namespace_path(group1.id), admin, admin_mode: true),
                params: { extra_shared_runners_minutes_limit: 1000 }
            end.to change { group1.reload.send(attr) }.to(nil)
          end
        end
      end

      context "when customer purchases extra compute minutes" do
        it "ticks instance runners" do
          runners = Ci::Runner.instance_type

          put api(namespace_path(group1.id), admin), params: { extra_shared_runners_minutes_limit: 1000 }

          expect(runners).to all(receive(:tick_runner_queue))
        end
      end

      context "when passing attributes for gitlab_subscription", :saas do
        let(:gitlab_subscription) do
          {
            start_date: '2019-06-01',
            end_date: '2020-06-01',
            plan_code: 'ultimate',
            seats: 20,
            max_seats_used: 10,
            auto_renew: true,
            trial: true,
            trial_starts_on: '2019-05-01',
            trial_ends_on: '2019-06-01',
            trial_extension_type: GitlabSubscription.trial_extension_types[:reactivated]
          }
        end

        it "creates the gitlab_subscription record" do
          expect(group1.gitlab_subscription).to be_nil

          put api(namespace_path(group1.id), admin, admin_mode: true), params: {
            gitlab_subscription_attributes: gitlab_subscription
          }

          expect(group1.reload.gitlab_subscription).to have_attributes(
            start_date: Date.parse(gitlab_subscription[:start_date]),
            end_date: Date.parse(gitlab_subscription[:end_date]),
            hosted_plan: instance_of(Plan),
            seats: 20,
            max_seats_used: 10,
            auto_renew: true,
            trial: true,
            trial_starts_on: Date.parse(gitlab_subscription[:trial_starts_on]),
            trial_ends_on: Date.parse(gitlab_subscription[:trial_ends_on]),
            trial_extension_type: 'reactivated'
          )
        end

        it "updates the gitlab_subscription record" do
          existing_subscription = group1.create_gitlab_subscription!

          put api(namespace_path(group1.id), admin, admin_mode: true), params: {
            gitlab_subscription_attributes: gitlab_subscription
          }

          expect(group1.reload.gitlab_subscription.reload.seats).to eq 20
          expect(group1.gitlab_subscription).to eq existing_subscription
        end

        context 'when params are invalid' do
          it 'returns a 400 error' do
            put api(namespace_path(group1.id), admin, admin_mode: true), params: {
              gitlab_subscription_attributes: { start_date: nil, seats: nil }
            }

            expect(response).to have_gitlab_http_status(:bad_request)
            expect(json_response['message']).to eq(
              "gitlab_subscription.seats" => ["can't be blank"],
              "gitlab_subscription.start_date" => ["can't be blank"]
            )
          end
        end
      end
    end
  end
end
