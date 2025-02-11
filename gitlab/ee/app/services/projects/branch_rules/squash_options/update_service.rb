# frozen_string_literal: true

module Projects
  module BranchRules
    module SquashOptions
      class UpdateService
        AUTHORIZATION_ERROR_MESSAGE = 'Not authorized'

        def initialize(branch_rule, squash_option:, current_user:)
          @branch_rule = branch_rule
          @squash_option = squash_option
          @current_user = current_user
        end

        def execute
          return ServiceResponse.error(message: AUTHORIZATION_ERROR_MESSAGE) unless authorized?

          ProtectedBranches::UpdateService.new(project, current_user, update_params).execute(protected_branch)

          return ServiceResponse.error(message: protected_branch.errors.full_messages) if protected_branch.errors.any?

          ServiceResponse.success(payload: protected_branch.squash_option)
        end

        private

        attr_reader :branch_rule, :squash_option, :current_user

        def update_params
          {
            squash_option_attributes: {
              protected_branch: protected_branch,
              project: project,
              squash_option: squash_option
            }
          }
        end

        def project
          branch_rule.project
        end

        def protected_branch
          branch_rule.protected_branch
        end

        def authorized?
          Ability.allowed?(current_user, :update_branch_rule, branch_rule)
        end
      end
    end
  end
end
