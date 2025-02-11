# frozen_string_literal: true

module API
  module Manage
    class Groups < ::API::Base
      feature_category :system_access

      include PaginationParams

      before do
        not_found! unless Feature.enabled?(:manage_pat_by_group_owners_ready, user_group)

        authenticate!
        authorize! :admin_group, user_group
      end

      helpers ::API::Helpers::PersonalAccessTokensHelpers

      helpers do
        def users
          user_group.enterprise_users
        end

        def pat_finder_params
          declared(params,
            include_missing: false).merge({ users: users, impersonation: false, sort: 'id_desc', owner_type: 'human' })
        end
      end

      namespace 'groups/:id/manage' do
        params do
          requires :id, type: String
        end

        resources :personal_access_tokens do
          params do
            use :access_token_params
            use :pagination
          end

          desc 'Get Personal access tokens' do
            detail 'This feature was introduced in GitLab 17.8.'
          end
          get do
            tokens = PersonalAccessTokensFinder.new(pat_finder_params).execute.preload_users

            present paginate(tokens), with: Entities::PersonalAccessToken
          end
        end
      end
    end
  end
end
