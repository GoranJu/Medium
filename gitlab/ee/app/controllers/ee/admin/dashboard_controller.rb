# frozen_string_literal: true

# rubocop:disable Gitlab/ModuleWithInstanceVariables
module EE
  module Admin
    module DashboardController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      override :index
      def index
        super

        @license = License.current
      end

      private

      override :authenticate_admin!
      def authenticate_admin!
        return if can?(current_user, :read_admin_dashboard)

        super
      end
    end
  end
end
