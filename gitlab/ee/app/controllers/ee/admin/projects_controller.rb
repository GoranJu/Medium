# frozen_string_literal: true

module EE
  module Admin
    module ProjectsController
      extend ActiveSupport::Concern

      prepended do
        before_action :limited_actions_message!, only: :show
        authorize! :read_admin_dashboard, only: [:index, :show]
      end
    end
  end
end
