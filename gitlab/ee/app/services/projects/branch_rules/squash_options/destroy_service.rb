# frozen_string_literal: true

module Projects
  module BranchRules
    module SquashOptions
      class DestroyService
        AUTHORIZATION_ERROR_MESSAGE = 'Not authorized'
        NOT_FOUND_ERROR_MESSAGE = 'Squash option not found'

        def initialize(branch_rule, current_user:)
          @branch_rule = branch_rule
          @current_user = current_user
        end

        def execute
          return ServiceResponse.error(message: AUTHORIZATION_ERROR_MESSAGE) unless authorized?
          return ServiceResponse.error(message: NOT_FOUND_ERROR_MESSAGE) if squash_option.blank?

          squash_option.destroy!
          ServiceResponse.success
        end

        private

        attr_reader :branch_rule, :current_user

        def authorized?
          Ability.allowed?(current_user, :update_branch_rule, branch_rule)
        end

        def squash_option
          branch_rule.protected_branch.squash_option
        end
      end
    end
  end
end
