# frozen_string_literal: true

module Sbom
  class ExportMailer < ApplicationMailer
    helper ::EmailsHelper
    helper ::DependenciesHelper

    layout 'mailer'

    def completion_email(export)
      @export = export
      @expiration_days = Dependencies::DependencyListExport::EXPIRES_AFTER.in_days.to_i

      exportable = export.exportable

      group = case exportable
              when ::Project
                exportable.group
              when ::Group
                exportable
              end

      mail_with_locale(
        to: export.author.notification_email_for(group),
        subject: s_('Dependencies|Dependency list export')
      )
    end
  end
end
