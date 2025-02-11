# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    # NOTE: Constants are scoped to the namespace in which they are used in production
    #       code (but they may still be referenced by specs or fixtures or factories).
    #       For example, this RemoteDevelopment::WorkspaceOperations::WorkspaceOperationsConstants
    #       file only contains constants which are used by multiple sub-namespaces
    #       of WorkspaceOperations, such as Create and Reconcile.
    #       Constants which are only used by a specific use-case sub-namespace
    #       like Create or Reconcile should be contained in the corresponding
    #       constants class such as CreateConstants or ReconcileConstants.
    #
    #       Multiple related constants may be declared in their own dedicated
    #       namespace, such as RemoteDevelopment::WorkspaceOperations::States.
    #
    #       See documentation at ../README.md#constant-declarations for more information.
    module WorkspaceOperationsConstants
      # Please keep alphabetized
      VARIABLES_FILE_DIR = "/.workspace-data/variables/file"
    end
  end
end
