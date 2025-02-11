# frozen_string_literal: true

module EE
  module GroupsFinder
    extend ::Gitlab::Utils::Override

    private

    override :filter_groups
    def filter_groups(groups)
      groups = super(groups)
      groups = by_marked_for_deletion_on(groups)
      groups = by_saml_sso_session(groups)
      by_repository_storage(groups)
    end

    def by_saml_sso_session(groups)
      return groups unless filter_expired_saml_session_groups?

      groups.by_not_in_root_id(current_user.expired_sso_session_saml_providers.select(:group_id))
    end

    def filter_expired_saml_session_groups?
      return false if current_user.nil? || current_user.can_read_all_resources?

      params.fetch(:filter_expired_saml_session_groups, false)
    end

    def by_repository_storage(groups)
      return groups if params[:repository_storage].blank?

      groups.by_repository_storage(params[:repository_storage])
    end

    def by_marked_for_deletion_on(groups)
      return groups unless params[:marked_for_deletion_on].present?
      return groups unless License.feature_available?(:adjourned_deletion_for_projects_and_groups)

      groups.by_marked_for_deletion_on(params[:marked_for_deletion_on])
    end
  end
end
