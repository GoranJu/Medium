# frozen_string_literal: true

module Projects
  module Filterable
    extend ActiveSupport::Concern

    private

    def by_saml_sso_session(projects)
      return projects unless filter_expired_saml_session_projects?

      projects.by_not_in_root_id(current_user.expired_sso_session_saml_providers.select(:group_id))
    end

    def filter_expired_saml_session_projects?
      return false if current_user.nil? || current_user.can_read_all_resources?

      params.fetch(:filter_expired_saml_session_projects, false)
    end
  end
end
