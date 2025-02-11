# frozen_string_literal: true

module Security
  module Findings
    class SeverityOverrideService < BaseService
      include Gitlab::Allowable

      def initialize(user:, security_finding:, severity:)
        super(security_finding.project, user)
        @security_finding = security_finding
        @severity = severity
      end

      def execute
        return service_error("Access denied", :forbidden) unless authorized?

        vulnerability_result = ::Vulnerabilities::FindOrCreateFromSecurityFindingService.new(
          project: @project,
          current_user: @current_user,
          state: @security_finding.state,
          present_on_default_branch: false,
          params: {
            security_finding_uuid: @security_finding.uuid
          }
        ).execute

        return lookup_error(vulnerability_result) unless vulnerability_result[:status] == :success

        vulnerability = vulnerability_result.payload[:vulnerability]
        update_severity(vulnerability)
        service_success
      rescue ArgumentError, ActiveRecord::RecordInvalid => error
        service_error(format_error(error.message), :unprocessable_entity)
      end

      private

      def authorized?
        can?(@current_user, :admin_vulnerability, @project) &&
          Feature.enabled?(:vulnerability_severity_override, @project&.root_ancestor)
      end

      def update_severity(vulnerability)
        return if vulnerability.severity == @severity

        vulnerability.transaction do
          create_severity_override_record(vulnerability)
          vulnerability.update!(severity: @severity)
          vulnerability.finding.update!(severity: @severity)
        end
        Vulnerabilities::Statistics::UpdateService.update_for(vulnerability)
      end

      def create_severity_override_record(vulnerability)
        Vulnerabilities::SeverityOverride.create!({
          vulnerability: vulnerability,
          original_severity: vulnerability.severity,
          new_severity: @severity,
          project_id: project.id,
          author_id: current_user.id
        })
      end

      def service_success
        @security_finding.severity = @severity # for the return finding to have the correct severity
        ServiceResponse.success(payload: { security_finding: @security_finding })
      end

      def service_error(msg, reason)
        ServiceResponse.error(message: msg, reason: reason)
      end

      def format_error(message)
        format(_("failed to change severity of security finding: %{message}"), message: message)
      end

      def lookup_error(result)
        service_error(format_error(result[:message].full_messages.join(",")), :unprocessable_entity)
      end
    end
  end
end
