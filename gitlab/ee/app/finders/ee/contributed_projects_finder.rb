# frozen_string_literal: true

module EE
  # ContributedProjectsFinder
  #
  # Extends ContributedProjectsFinder
  #
  # Added arguments:
  #   params:
  #     filter_expired_saml_session_projects: boolean
  module ContributedProjectsFinder # rubocop:disable Gitlab/BoundedContexts -- needs same bounded context as CE version
    include ::Projects::Filterable
    extend ::Gitlab::Utils::Override

    private

    override :filter_projects
    def filter_projects(collection)
      by_saml_sso_session(super)
    end
  end
end
