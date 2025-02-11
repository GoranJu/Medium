# frozen_string_literal: true

module Types
  module ProductAnalytics
    class CategoryEnum < BaseEnum
      graphql_name 'CustomizableDashboardCategory'
      description 'Categories for customizable dashboards.'

      value 'ANALYTICS', value: 'analytics', description: 'Analytics category for customizable dashboards.'
    end
  end
end
