# frozen_string_literal: true

module Types
  module Projects
    # rubocop: disable Graphql/AuthorizeTypes -- parent handles auth
    class SettingType < BaseObject
      graphql_name 'ProjectSetting'

      field :duo_features_enabled,
        GraphQL::Types::Boolean,
        null: true,
        description: 'Indicates whether GitLab Duo features are enabled for the project.'

      field :project,
        Types::ProjectType,
        null: true,
        description: 'Project the settings belong to.'
    end
    # rubocop: enable Graphql/AuthorizeTypes
  end
end
