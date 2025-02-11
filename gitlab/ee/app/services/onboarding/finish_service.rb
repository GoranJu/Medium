# frozen_string_literal: true

module Onboarding
  class FinishService
    def initialize(user)
      @user = user
    end

    def execute
      return unless Onboarding.user_onboarding_in_progress?(user)

      user.update(onboarding_in_progress: false)
    end

    private

    attr_reader :user
  end
end
