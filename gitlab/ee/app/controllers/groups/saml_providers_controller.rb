# frozen_string_literal: true
require_relative '../concerns/saml_authorization'

class Groups::SamlProvidersController < Groups::ApplicationController
  include SamlAuthorization
  include SafeFormatHelper
  include MicrosoftApplicationActions

  before_action :require_top_level_group
  before_action :authorize_manage_saml!
  before_action :check_group_saml_available!
  before_action :check_group_saml_configured
  before_action :find_or_initialize_microsoft_application, only: [:show]

  feature_category :system_access

  def show
    @saml_provider = @group.saml_provider || @group.build_saml_provider
    @saml_response_check = load_test_response if @saml_provider.persisted?

    scim_token = if Feature.enabled?(:separate_group_scim_table, @group)
                   GroupScimAuthAccessToken.find_by_group_id(@group.id)
                 else
                   ScimOauthAccessToken.find_by_group_id(@group.id)
                 end

    @scim_token_url = scim_token.as_entity_json[:scim_api_url] if scim_token
  end

  def create
    create_service = GroupSaml::SamlProvider::CreateService.new(current_user, @group, params: saml_provider_params)

    create_service.execute

    @saml_provider = create_service.saml_provider

    render :show
  end

  def update
    @saml_provider = @group.saml_provider

    GroupSaml::SamlProvider::UpdateService.new(current_user, @saml_provider, params: saml_provider_params).execute

    render :show
  end

  private

  def load_test_response
    test_response = Gitlab::Auth::GroupSaml::ResponseStore.new(session.id).get_raw
    return if test_response.blank?

    Gitlab::Auth::GroupSaml::ResponseCheck.for_group(group: @group, raw_response: test_response, user: current_user)
  end

  def saml_provider_params
    allowed_params = [
      :sso_url,
      :certificate_fingerprint,
      :enabled,
      :disable_password_authentication_for_enterprise_users,
      :enforced_sso,
      :default_membership_role,
      :git_check_enforced
    ]
    allowed_params << :member_role_id if group.custom_roles_enabled?

    if Feature.enabled?(:group_managed_accounts, group)
      allowed_params += [:enforced_group_managed_accounts, :prohibited_outer_forks]
    end

    params.require(:saml_provider).permit(allowed_params)
  end

  def microsoft_application_namespace
    @group
  end

  def microsoft_application_redirect_path
    group_saml_providers_path(group)
  end

  def microsoft_group_sync_enabled?
    @group.saml_provider&.enabled?
  end
end
