# frozen_string_literal: true

module EE
  module Projects
    module AllBranchesRule
      extend ::Gitlab::Utils::Override

      def approval_project_rules
        project.approval_rules.for_all_branches
      end

      def external_status_checks
        project.external_status_checks.for_all_branches
      end
    end
  end
end
