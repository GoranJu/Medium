# frozen_string_literal: true

module Mutations
  module ComplianceManagement
    module ComplianceFramework
      module ComplianceRequirements
        class Update < BaseMutation
          graphql_name 'UpdateComplianceRequirement'
          authorize :admin_compliance_framework

          argument :id, ::Types::GlobalIDType[::ComplianceManagement::ComplianceFramework::ComplianceRequirement],
            required: true,
            description: 'Global ID of the compliance requirement to update.'

          argument :params, Types::ComplianceManagement::ComplianceRequirementInputType,
            required: true,
            description: 'Parameters to update the compliance requirement with.'

          field :requirement,
            Types::ComplianceManagement::ComplianceRequirementType,
            null: true,
            description: 'Compliance requirement after updation.'

          def resolve(id:, **args)
            requirement = authorized_find!(id: id)

            ::ComplianceManagement::ComplianceFramework::ComplianceRequirements::UpdateService.new(
              requirement: requirement,
              current_user: current_user,
              params: args[:params].to_h).execute

            { requirement: requirement, errors: errors_on_object(requirement) }
          end
        end
      end
    end
  end
end
