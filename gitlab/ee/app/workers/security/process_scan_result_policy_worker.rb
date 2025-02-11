# frozen_string_literal: true

module Security
  class ProcessScanResultPolicyWorker
    include ApplicationWorker

    idempotent!
    deduplicate :until_executed, if_deduplicated: :reschedule_once, including_scheduled: true

    data_consistency :always
    sidekiq_options retry: true
    feature_category :security_policy_management

    concurrency_limit -> { 200 }

    HISTOGRAMS = {
      process: :gitlab_security_policies_scan_result_process_duration_seconds,
      policy_sync: :gitlab_security_policies_policy_sync_duration_seconds,
      policy_deletion: :gitlab_security_policies_policy_deletion_duration_seconds,
      policy_creation: :gitlab_security_policies_policy_creation_duration_seconds
    }.freeze

    def perform(project_id, configuration_id)
      @project = Project.find_by_id(project_id)
      @configuration = Security::OrchestrationPolicyConfiguration.find_by_id(configuration_id)
      return unless project && configuration

      return if Feature.enabled?(:use_approval_policy_rules_for_approval_rules, project)

      measure_and_log(:process) do
        sync_policies(project, configuration)

        Security::SecurityOrchestrationPolicies::SyncOpenedMergeRequestsService
          .new(project: project, policy_configuration: configuration)
          .execute
      end
    end

    private

    attr_reader :project, :configuration

    def sync_policies(project, configuration)
      measure_and_log(:policy_sync) do
        measure_and_log(:policy_deletion) do
          configuration.delete_scan_finding_rules_for_project(project.id)
          configuration.delete_software_license_policies_for_project(project)
          configuration.delete_policy_violations_for_project(project)
          configuration.delete_scan_result_policy_reads_for_project(project)
        end

        measure_and_log(:policy_creation) do
          configuration
            .applicable_scan_result_policies_with_real_index(project) do |policy, real_policy_idx, policy_idx|
            Security::SecurityOrchestrationPolicies::ProcessScanResultPolicyService.new(
              project: project,
              policy_configuration: configuration,
              policy: policy,
              policy_index: policy_idx,
              real_policy_index: real_policy_idx
            ).execute
          end
        end
      end
    end

    def measure_and_log(event, &)
      measure(HISTOGRAMS[event], callback: ->(duration) { log_duration(event, duration) }, &)
    end

    def log_duration(event, duration)
      Gitlab::AppJsonLogger.debug(
        build_structured_payload(
          event: event,
          duration: duration,
          configuration_id: configuration.id,
          project_id: project.id))
    end

    delegate :measure, to: Security::SecurityOrchestrationPolicies::ObserveHistogramsService
  end
end
