# frozen_string_literal: true

module Authz
  class Admin
    def initialize(user)
      @user = user
    end

    def permitted
      ::Preloaders::UserMemberRolesForAdminPreloader
        .new(user: user)
        .execute[:admin]
    end

    private

    attr_reader :user
  end
end
