# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.member_role_permissions', feature_category: :permissions do
  include GraphqlHelpers

  let(:fields) do
    <<~QUERY
      nodes {
        availableFor
        description
        name
        requirements
        value
        enabledForGroupAccessLevels
        enabledForProjectAccessLevels
        availableFromAccessLevel {
          integerValue
        }
      }
    QUERY
  end

  let(:mock_permissions) do
    {
      admin_ability_one: {
        title: 'Admin something',
        description: 'Allows admin access to do something.',
        project_ability: true,
        available_from_access_level: 50,
        enabled_for_project_access_levels: [50]
      },
      admin_ability_two: {
        title: 'Admin something else',
        description: 'Allows admin access to do something else.',
        requirements: [:read_ability_two],
        group_ability: true,
        enabled_for_group_access_levels: [40, 50]
      },
      read_ability_two: {
        title: 'Read something else',
        description: 'Allows read access to do something else.',
        group_ability: true,
        project_ability: true,
        enabled_for_group_access_levels: [20, 30, 40, 50],
        enabled_for_project_access_levels: [20, 30, 40, 50]
      }
    }
  end

  let(:query) do
    graphql_query_for('memberRolePermissions', fields)
  end

  def redefine_enum!
    # We need to override the enum values, because they are defined at boot time
    # and stubbing the permissions won't have an effect.
    Types::MemberRoles::PermissionsEnum.class_eval do
      def self.enum_values(_)
        MemberRole.all_customizable_permissions.map do |key, _|
          enum_value_class.new(key.upcase, value: key, owner: self)
        end
      end
    end
  end

  def reset_enum!
    # Remove the override
    Types::MemberRoles::PermissionsEnum.singleton_class.remove_method(:enum_values)
  end

  before do
    allow(MemberRole).to receive_messages(
      all_customizable_permissions: mock_permissions,
      all_customizable_standard_permissions: mock_permissions
    )

    redefine_enum!

    post_graphql(query)
  end

  after do
    reset_enum!
  end

  subject { graphql_data.dig('memberRolePermissions', 'nodes') }

  it_behaves_like 'a working graphql query'

  it 'returns all customizable ablities', :unlimited_max_formatted_output_length do
    expected_result = [
      { 'availableFor' => ['project'], 'description' => 'Allows admin access to do something.',
        'name' => 'Admin something', 'requirements' => nil, 'value' => 'ADMIN_ABILITY_ONE',
        'availableFromAccessLevel' => { 'integerValue' => 50 }, 'enabledForGroupAccessLevels' => nil,
        'enabledForProjectAccessLevels' => ['OWNER'] },
      { 'availableFor' => %w[project group], 'description' => 'Allows read access to do something else.',
        'name' => 'Read something else', 'requirements' => nil, 'value' => 'READ_ABILITY_TWO',
        'availableFromAccessLevel' => nil, 'enabledForGroupAccessLevels' => %w[REPORTER DEVELOPER MAINTAINER OWNER],
        'enabledForProjectAccessLevels' => %w[REPORTER DEVELOPER MAINTAINER OWNER] },
      { 'availableFor' => ['group'], 'description' => "Allows admin access to do something else.",
        'requirements' => ['READ_ABILITY_TWO'], 'name' => 'Admin something else', 'value' => 'ADMIN_ABILITY_TWO',
        'availableFromAccessLevel' => nil, 'enabledForGroupAccessLevels' => %w[MAINTAINER OWNER],
        'enabledForProjectAccessLevels' => nil }
    ]

    expect(subject).to match_array(expected_result)
  end
end
