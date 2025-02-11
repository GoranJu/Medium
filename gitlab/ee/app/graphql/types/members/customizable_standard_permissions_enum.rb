# frozen_string_literal: true

module Types
  module Members
    class CustomizableStandardPermissionsEnum < BaseEnum
      graphql_name 'MemberRoleStandardPermission'
      description 'Member role standard permission'

      MemberRole.all_customizable_standard_permissions.each_pair do |key, value|
        value key.upcase, value: key, description: value[:description]
      end
    end
  end
end
