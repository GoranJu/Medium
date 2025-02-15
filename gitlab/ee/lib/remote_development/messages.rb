# frozen_string_literal: true

module RemoteDevelopment
  # This module contains all messages for the EE part of the Remote Development domain, both errors and domain events.
  # Note that we intentionally have not DRY'd up the declaration of the subclasses with loops and
  # metaprogramming, because we want the types to be easily indexable and navigable within IDEs.
  module Messages
    #---------------------------------------------------------------
    # Errors - message name should describe the reason for the error
    #---------------------------------------------------------------

    # License error
    LicenseCheckFailed = Class.new(Gitlab::Fp::Message)

    # AgentConfigOperations errors
    AgentConfigUpdateFailed = Class.new(Gitlab::Fp::Message)

    # Workspace create errors
    WorkspaceCreateParamsValidationFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceCreateDevfileLoadFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceCreateDevfileYamlParseFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceCreatePreFlattenDevfileValidationFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceCreateDevfileFlattenFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceCreatePostFlattenDevfileValidationFailed = Class.new(Gitlab::Fp::Message)
    PersonalAccessTokenModelCreateFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceModelCreateFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceVariablesModelCreateFailed = Class.new(Gitlab::Fp::Message)
    WorkspaceCreateFailed = Class.new(Gitlab::Fp::Message)

    # Workspace update errors
    WorkspaceUpdateFailed = Class.new(Gitlab::Fp::Message)

    # Workspace reconcile errors
    WorkspaceReconcileParamsValidationFailed = Class.new(Gitlab::Fp::Message)

    # Namespace Cluster Agent Mapping create errors
    NamespaceClusterAgentMappingAlreadyExists = Class.new(Gitlab::Fp::Message)
    NamespaceClusterAgentMappingCreateFailed = Class.new(Gitlab::Fp::Message)
    NamespaceClusterAgentMappingCreateValidationFailed = Class.new(Gitlab::Fp::Message)

    # Namespace Cluster Agent Mapping delete errors
    NamespaceClusterAgentMappingNotFound = Class.new(Gitlab::Fp::Message)

    #---------------------------------------------------------
    # Domain Events - message name should describe the outcome
    #---------------------------------------------------------

    # AgentConfigOperations domain events
    AgentConfigUpdateSkippedBecauseNoConfigFileEntryFound = Class.new(Gitlab::Fp::Message)
    AgentConfigUpdateSuccessful = Class.new(Gitlab::Fp::Message)

    # Workspace domain events
    WorkspaceCreateSuccessful = Class.new(Gitlab::Fp::Message)
    WorkspaceUpdateSuccessful = Class.new(Gitlab::Fp::Message)
    WorkspaceReconcileSuccessful = Class.new(Gitlab::Fp::Message)

    # Namespace Cluster Agent Mapping domain events
    NamespaceClusterAgentMappingCreateSuccessful = Class.new(Gitlab::Fp::Message)
    NamespaceClusterAgentMappingDeleteSuccessful = Class.new(Gitlab::Fp::Message)
  end
end
