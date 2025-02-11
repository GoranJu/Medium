# frozen_string_literal: true

module SamlGroupLinksHelper
  def saml_group_link_input_names
    {
      base_access_level_input_name: "saml_group_link[access_level]",
      member_role_id_input_name: "saml_group_link[member_role_id]"
    }
  end

  # For SaaS only. Self-managed configures add-on groups in the configuration file.
  def duo_seat_assignment_available?(group)
    return false unless Feature.enabled?(:saml_groups_duo_add_on_assignment, group)
    return false unless ::Gitlab::Saas.feature_available?(:gitlab_duo_saas_only)
    return false if group.has_parent?

    add_on_purchase = GitlabSubscriptions::Duo.enterprise_or_pro_for_namespace(group)
    return false unless add_on_purchase.present?

    add_on_purchase.active?
  end
end
