# frozen_string_literal: true

class Groups::ScimOauthController < Groups::ApplicationController
  include SamlAuthorization

  before_action :require_top_level_group
  before_action :authorize_manage_saml!
  before_action :check_group_saml_available!
  before_action :check_group_saml_configured

  feature_category :system_access

  # rubocop: disable CodeReuse/ActiveRecord
  def create
    scim_token = if Feature.enabled?(:separate_group_scim_table, @group)
                   GroupScimAuthAccessToken.find_or_initialize_by(group: @group)
                 else
                   ScimOauthAccessToken.find_or_initialize_by(group: @group)
                 end

    if scim_token.new_record?
      scim_token.save
    else
      scim_token.reset_token!
    end

    respond_to do |format|
      format.json do
        if scim_token.valid?
          render json: scim_token.as_entity_json
        else
          render json: { errors: scim_token.errors.full_messages }, status: :unprocessable_entity
        end
      end
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord
end
