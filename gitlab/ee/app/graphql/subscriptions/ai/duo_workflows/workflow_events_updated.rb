# frozen_string_literal: true

module Subscriptions # rubocop:disable Gitlab/BoundedContexts -- Existing module
  module Ai
    module DuoWorkflows
      class WorkflowEventsUpdated < BaseSubscription
        include Gitlab::Graphql::Laziness

        payload_type ::Types::Ai::DuoWorkflows::WorkflowEventType

        argument :workflow_id, Types::GlobalIDType[::Ai::DuoWorkflows::Workflow],
          required: true,
          description: 'Workflow ID to fetch duo workflow.'
        def authorized?(args)
          unauthorized! unless current_user

          workflow = force(GitlabSchema.find_by_gid(args[:workflow_id]))
          unauthorized! unless workflow && Ability.allowed?(current_user, :read_duo_workflow, workflow)

          true
        end
      end
    end
  end
end
