# frozen_string_literal: true

module Types
  module Sbom
    class ReachabilityEnum < BaseEnum
      graphql_name 'ReachabilityType'
      description 'Dependency reachability status'

      value 'UNKNOWN', value: 'unknown', description: "Dependency reachability status is unknown."
      value 'IN_USE', value: 'in_use', description: "Dependency is imported and in use."
    end
  end
end
