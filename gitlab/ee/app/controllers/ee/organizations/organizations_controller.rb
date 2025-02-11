# frozen_string_literal: true

module EE
  module Organizations
    module OrganizationsController
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        before_action only: [:show, :groups_and_projects] do
          push_licensed_feature(:adjourned_deletion_for_projects_and_groups)
        end
      end
    end
  end
end
