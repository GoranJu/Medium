# frozen_string_literal: true

module EE
  module Resolvers
    module Projects
      module UserContributedProjectsResolver
        extend ::Gitlab::Utils::Override

        override :finder_params
        def finder_params(args)
          # Expired SAML session filter disabled for now.
          # Further investigation needed in https://gitlab.com/gitlab-org/gitlab/-/issues/514406
          super.merge(filter_expired_saml_session_projects: false)
        end
      end
    end
  end
end
