# frozen_string_literal: true

module EE
  module Gitlab
    module EventStore
      extend ActiveSupport::Concern

      class_methods do
        extend ::Gitlab::Utils::Override
        # Define event subscriptions using:
        #
        #   store.subscribe(DomainA::SomeWorker, to: DomainB::SomeEvent)
        #
        # It is possible to subscribe to a subset of events matching a condition:
        #
        #   store.subscribe(DomainA::SomeWorker, to: DomainB::SomeEvent), if: ->(event) { event.data == :some_value }
        #
        # Only EE subscriptions should be declared in this module.
        override :configure!
        def configure!(store)
          super(store)

          ###
          # Add EE only subscriptions here:

          store.subscribe ::Security::Scans::PurgeByJobIdWorker, to: ::Ci::JobArtifactsDeletedEvent
          store.subscribe ::Geo::CreateRepositoryUpdatedEventWorker,
            to: ::Repositories::KeepAroundRefsCreatedEvent,
            if: ->(_) { ::Gitlab::Geo.primary? }
          store.subscribe ::MergeRequests::StreamApprovalAuditEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::ApprovalMetricsEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::CreateApprovalsResetNoteWorker, to: ::MergeRequests::ApprovalsResetEvent
          store.subscribe ::PullMirrors::ReenableConfigurationWorker, to: ::GitlabSubscriptions::RenewedEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
            to: ::MergeRequests::ExternalStatusCheckPassedEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::UnblockedStateEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
            to: ::MergeRequests::JiraTitleDescriptionUpdateEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker,
            to: ::MergeRequests::OverrideRequestedChangesStateEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::ApprovedEvent
          store.subscribe ::MergeRequests::ProcessAutoMergeFromEventWorker, to: ::MergeRequests::ViolationsUpdatedEvent
          store.subscribe ::Search::ElasticDefaultBranchChangedWorker,
            to: ::Repositories::DefaultBranchChangedEvent,
            if: ->(_) { ::Gitlab::CurrentSettings.elasticsearch_indexing? }
          store.subscribe ::Search::Zoekt::DefaultBranchChangedWorker, to: ::Repositories::DefaultBranchChangedEvent
          store.subscribe ::Search::Zoekt::DeleteProjectEventWorker,
            to: ::Projects::ProjectDeletedEvent, if: ->(_) { ::Search::Zoekt.licensed_and_indexing_enabled? }
          store.subscribe ::Search::Zoekt::TaskFailedEventWorker, to: ::Search::Zoekt::TaskFailedEvent
          store.subscribe ::PackageMetadata::GlobalAdvisoryScanWorker, to: ::PackageMetadata::IngestedAdvisoryEvent
          store.subscribe ::Sbom::ProcessVulnerabilitiesWorker, to: ::Sbom::SbomIngestedEvent
          store.subscribe ::Sbom::CreateOccurrencesVulnerabilitiesWorker, to: ::Sbom::VulnerabilitiesCreatedEvent
          store.subscribe ::Llm::NamespaceAccessCacheResetWorker, to: ::NamespaceSettings::AiRelatedSettingsChangedEvent
          store.subscribe ::Security::RefreshProjectPoliciesWorker,
            to: ::ProjectAuthorizations::AuthorizationsChangedEvent,
            delay: 1.minute
          store.subscribe ::MergeRequests::RemoveUserApprovalRulesWorker,
            to: ::ProjectAuthorizations::AuthorizationsRemovedEvent
          store.subscribe ::Security::ScanResultPolicies::AddApproversToRulesWorker,
            to: ::ProjectAuthorizations::AuthorizationsAddedEvent,
            if: ->(event) { ::Security::ScanResultPolicies::AddApproversToRulesWorker.dispatch?(event) }
          store.subscribe ::Security::RefreshComplianceFrameworkSecurityPoliciesWorker,
            to: ::Projects::ComplianceFrameworkChangedEvent
          store.subscribe ::AppSec::ContainerScanning::ScanImageWorker,
            to: ::ContainerRegistry::ImagePushedEvent,
            delay: 1.minute,
            if: ->(event) { ::AppSec::ContainerScanning::ScanImageWorker.dispatch?(event) }
          store.subscribe ::GitlabSubscriptions::MemberManagement::ApplyPendingMemberApprovalsWorker,
            to: ::Members::MembershipModifiedByAdminEvent,
            if: ->(_) {
              ::Gitlab::CurrentSettings.enable_member_promotion_management? &&
                ::Feature.enabled?(:member_promotion_management, :instance, type: :beta)
            }

          register_threat_insights_subscribers(store)
          register_security_policy_subscribers(store)

          subscribe_to_epic_events(store)
          subscribe_to_external_issue_links_events(store)
          subscribe_to_work_item_events(store)
          subscribe_to_milestone_events(store)
          subscribe_to_zoekt_events(store)
          subscribe_to_members_added_event(store)
          subscribe_to_users_activity_events(store)
          subscribe_to_member_destroyed_events(store)
          subscribe_to_merge_events(store)
        end

        def subscribe_to_member_destroyed_events(store)
          store.subscribe ::GitlabSubscriptions::Members::DestroyedWorker, to: ::Members::DestroyedEvent
        end

        def register_security_policy_subscribers(store)
          store.subscribe ::Security::SyncPolicyWorker, to: ::Security::PolicyCreatedEvent
          store.subscribe ::Security::SyncPolicyWorker, to: ::Security::PolicyDeletedEvent
          store.subscribe ::Security::SyncPolicyWorker, to: ::Security::PolicyUpdatedEvent

          store.subscribe ::Security::SyncPolicyEventWorker, to: ::Repositories::ProtectedBranchCreatedEvent
          store.subscribe ::Security::SyncPolicyEventWorker, to: ::Repositories::ProtectedBranchDestroyedEvent
        end

        def register_threat_insights_subscribers(store)
          store.subscribe ::Sbom::ProcessTransferEventsWorker, to: ::Projects::ProjectTransferedEvent
          store.subscribe ::Sbom::ProcessTransferEventsWorker, to: ::Groups::GroupTransferedEvent
          store.subscribe ::Sbom::SyncArchivedStatusWorker, to: ::Projects::ProjectArchivedEvent

          store.subscribe ::Vulnerabilities::ProcessTransferEventsWorker, to: ::Projects::ProjectTransferedEvent
          store.subscribe ::Vulnerabilities::ProcessTransferEventsWorker, to: ::Groups::GroupTransferedEvent
          store.subscribe ::Vulnerabilities::ProcessArchivedEventsWorker, to: ::Projects::ProjectArchivedEvent

          store.subscribe ::Vulnerabilities::NamespaceHistoricalStatistics::ProcessTransferEventsWorker,
            to: ::Groups::GroupTransferedEvent
        end

        def subscribe_to_epic_events(store)
          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::Epics::EpicCreatedEvent,
            if: ->(event) {
              ::Feature.enabled?(:validate_epic_work_item_sync, ::Group.actor_from_id(event.data[:group_id]))
            }
          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::Epics::EpicUpdatedEvent,
            if: ->(event) {
              ::Feature.enabled?(:validate_epic_work_item_sync, ::Group.actor_from_id(event.data[:group_id]))
            }
        end

        def subscribe_to_external_issue_links_events(store)
          store.subscribe ::VulnerabilityExternalIssueLinks::UpdateVulnerabilityRead,
            to: ::Vulnerabilities::LinkToExternalIssueTrackerCreated

          store.subscribe ::VulnerabilityExternalIssueLinks::UpdateVulnerabilityRead,
            to: ::Vulnerabilities::LinkToExternalIssueTrackerRemoved
        end

        def subscribe_to_work_item_events(store)
          store.subscribe ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler,
            to: ::WorkItems::WorkItemCreatedEvent
          store.subscribe ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler,
            to: ::WorkItems::WorkItemDeletedEvent
          store.subscribe ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler,
            to: ::WorkItems::WorkItemUpdatedEvent,
            if: ->(event) {
              ::WorkItems::RolledupDates::UpdateRolledupDatesEventHandler.can_handle_update?(event)
            }

          store.subscribe ::WorkItems::RolledupDates::BulkUpdateHandler,
            to: ::WorkItems::BulkUpdatedEvent,
            if: ->(event) {
              ::WorkItems::RolledupDates::BulkUpdateHandler.can_handle?(event)
            }

          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::WorkItems::WorkItemCreatedEvent,
            if: ->(event) { ::WorkItems::ValidateEpicWorkItemSyncWorker.can_handle?(event) }

          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::WorkItems::WorkItemUpdatedEvent,
            if: ->(event) { ::WorkItems::ValidateEpicWorkItemSyncWorker.can_handle?(event) }

          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::WorkItems::WorkItemClosedEvent,
            if: ->(event) { ::WorkItems::ValidateEpicWorkItemSyncWorker.can_handle?(event) }

          store.subscribe ::WorkItems::ValidateEpicWorkItemSyncWorker,
            to: ::WorkItems::WorkItemReopenedEvent,
            if: ->(event) { ::WorkItems::ValidateEpicWorkItemSyncWorker.can_handle?(event) }
        end

        def subscribe_to_milestone_events(store)
          store.subscribe ::WorkItems::RolledupDates::UpdateMilestoneRelatedWorkItemDatesEventHandler,
            to: ::Milestones::MilestoneUpdatedEvent,
            if: ->(event) {
              ::WorkItems::RolledupDates::UpdateMilestoneRelatedWorkItemDatesEventHandler.can_handle?(event)
            }
        end

        def subscribe_to_zoekt_events(store)
          store.subscribe ::Search::Zoekt::IndexMarkAsPendingEvictionEventWorker,
            to: ::Search::Zoekt::IndexMarkPendingEvictionEvent

          store.subscribe ::Search::Zoekt::OrphanedIndexEventWorker,
            to: ::Search::Zoekt::OrphanedIndexEvent

          store.subscribe ::Search::Zoekt::IndexMarkedAsToDeleteEventWorker,
            to: ::Search::Zoekt::IndexMarkedAsToDeleteEvent

          store.subscribe ::Search::Zoekt::OrphanedRepoEventWorker,
            to: ::Search::Zoekt::OrphanedRepoEvent

          store.subscribe ::Search::Zoekt::RepoMarkedAsToDeleteEventWorker,
            to: ::Search::Zoekt::RepoMarkedAsToDeleteEvent

          store.subscribe ::Search::Zoekt::IndexWatermarkChangedEventWorker,
            to: ::Search::Zoekt::IndexWatermarkChangedEvent

          store.subscribe ::Search::Zoekt::InitialIndexingEventWorker,
            to: ::Search::Zoekt::InitialIndexingEvent

          store.subscribe ::Search::Zoekt::LostNodeEventWorker,
            to: ::Search::Zoekt::LostNodeEvent

          store.subscribe ::Search::Zoekt::RepoToIndexEventWorker,
            to: ::Search::Zoekt::RepoToIndexEvent

          store.subscribe ::Search::Zoekt::IndexToEvictEventWorker,
            to: ::Search::Zoekt::IndexToEvictEvent

          store.subscribe ::Search::Zoekt::AdjustIndicesReservedStorageBytesEventWorker,
            to: ::Search::Zoekt::AdjustIndicesReservedStorageBytesEvent

          store.subscribe ::Search::Zoekt::NodeWithNegativeUnclaimedStorageEventWorker,
            to: ::Search::Zoekt::NodeWithNegativeUnclaimedStorageEvent

          store.subscribe ::Search::Zoekt::IndexMarkedAsReadyEventWorker,
            to: ::Search::Zoekt::IndexMarkedAsReadyEvent

          store.subscribe ::Search::Zoekt::UpdateIndexUsedStorageBytesEventWorker,
            to: ::Search::Zoekt::UpdateIndexUsedStorageBytesEvent

          store.subscribe ::Search::Zoekt::SaasRolloutEventWorker,
            to: ::Search::Zoekt::SaasRolloutEvent
        end

        def subscribe_to_members_added_event(store)
          store.subscribe ::Llm::NamespaceAccessCacheResetWorker, to: ::Members::MembersAddedEvent

          store.subscribe ::GitlabSubscriptions::Members::AddedWorker, to: ::Members::MembersAddedEvent
        end

        def subscribe_to_users_activity_events(store)
          store.subscribe ::GitlabSubscriptions::Members::RecordLastActivityWorker,
            to: ::Users::ActivityEvent,
            if: ->(event) {
              namespace_id = event.data[:namespace_id]

              !GitlabSubscriptions::Members::ActivityService.lease_taken?(
                namespace_id, event.data[:user_id]
              )
            }
        end

        def subscribe_to_merge_events(store)
          store.subscribe ::MergeRequests::ProcessMergeAuditEventWorker, to: ::MergeRequests::MergedEvent
        end
      end
    end
  end
end
