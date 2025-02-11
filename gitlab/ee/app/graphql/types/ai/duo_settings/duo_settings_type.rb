# frozen_string_literal: true

module Types
  module Ai
    module DuoSettings
      class DuoSettingsType < ::Types::BaseObject # rubocop:disable Graphql/AuthorizeTypes -- already authorized through resolver
        graphql_name 'DuoSettings'
        description 'GitLab Duo settings'

        field :ai_gateway_url, String,
          null: true,
          description: 'URL for local AI gateway server.',
          experiment: { milestone: '17.9' }

        field :updated_at, Types::TimeType,
          null: false,
          description: 'Timestamp of last GitLab Duo setting update.',
          experiment: { milestone: '17.9' }
      end
    end
  end
end
