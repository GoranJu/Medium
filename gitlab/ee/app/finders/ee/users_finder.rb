# frozen_string_literal: true

module EE
  module UsersFinder
    extend ::Gitlab::Utils::Override

    override :execute
    def execute
      users = by_non_ldap(super)
      users = by_saml_provider_id(users)
      users = by_auditors(users) if ::License.feature_available?(:auditor_user)
      order(users)
    end

    def by_non_ldap(users)
      return users unless params[:skip_ldap]

      users.non_ldap
    end

    def by_saml_provider_id(users)
      saml_provider_id = params[:saml_provider_id]
      return users unless saml_provider_id

      users.limit_to_saml_provider(saml_provider_id)
    end

    override :by_external_identity
    def by_external_identity(users)
      return users unless params[:extern_uid] && params[:provider]
      return super unless params[:provider] == "scim"

      if ::Gitlab.com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- SaaS scim is not marked as separate feature
        users.with_group_scim_identities_by_extern_uid(params[:extern_uid])
      else
        users.with_instance_scim_identities_by_extern_uid(params[:extern_uid])
      end
    end

    def by_auditors(users)
      # can_read_all_resources to ensure user is administrator
      return users unless params[:auditors] && current_user&.can_read_all_resources?

      users.auditors
    end
  end
end
