# frozen_string_literal: true

module MicrosoftApplicationActions
  extend ActiveSupport::Concern
  include SafeFormatHelper

  included do
    feature_category :system_access, [:update_microsoft_application]

    before_action :check_microsoft_group_sync_available, only: [:update_microsoft_application]
  end

  def update_microsoft_application
    params = microsoft_application_params.dup
    params.delete(:client_secret) if params[:client_secret].blank?

    result = update_microsoft_application_model(params)

    if result[:status]
      flash[:notice] = s_('Microsoft|Microsoft Azure integration settings were successfully updated.')
    else
      flash[:alert] = safe_format(
        s_('Microsoft|Microsoft Azure integration settings failed to save. %{errors}'),
        errors: result[:errors].to_sentence
      )
    end

    redirect_to microsoft_application_redirect_path
  end

  private

  # rubocop:disable Gitlab/ModuleWithInstanceVariables, CodeReuse/ActiveRecord -- migrating legacy code to new table
  def find_or_initialize_microsoft_application
    return unless microsoft_group_sync_enabled?

    @microsoft_application = # rubocop:disable Gitlab/ModuleWithInstanceVariables
      ::SystemAccess::MicrosoftApplication.find_or_initialize_by(namespace: microsoft_application_namespace) # rubocop:disable CodeReuse/ActiveRecord
  end
  # rubocop:enable Gitlab/ModuleWithInstanceVariables, CodeReuse/ActiveRecord

  # rubocop:disable CodeReuse/ActiveRecord -- migrating legacy code to new table
  def update_microsoft_application_model(params)
    if microsoft_application_namespace.nil?
      instance_app = ::SystemAccess::MicrosoftApplication.find_or_initialize_by(
        namespace: microsoft_application_namespace
      )
      status = instance_app.update(params)
      return { status: status, errors: instance_app.errors.full_messages }
    end

    group_app = ::SystemAccess::GroupMicrosoftApplication.find_or_initialize_by(
      group: microsoft_application_namespace
    )
    legacy_app = ::SystemAccess::MicrosoftApplication.find_or_initialize_by(
      namespace: microsoft_application_namespace
    )

    group_app_result = nil
    legacy_app_result = nil

    ::SystemAccess::GroupMicrosoftApplication.transaction do
      group_app_result = group_app.update(params)
      legacy_app_result = legacy_app.update(params)

      raise ActiveRecord::Rollback unless group_app_result && legacy_app_result
    end

    errors = group_app.errors.full_messages + legacy_app.errors.full_messages

    {
      status: group_app_result && legacy_app_result,
      errors: errors.uniq
    }
  end
  # rubocop:enable CodeReuse/ActiveRecord

  def check_microsoft_group_sync_available
    render_404 unless microsoft_group_sync_enabled?
  end

  def microsoft_application_params
    params.require(:system_access_microsoft_application)
          .permit(:enabled, :tenant_xid, :client_xid, :client_secret, :login_endpoint, :graph_endpoint)
  end
end
