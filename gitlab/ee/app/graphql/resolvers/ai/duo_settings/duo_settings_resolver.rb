# frozen_string_literal: true

module Resolvers
  module Ai
    module DuoSettings
      class DuoSettingsResolver < BaseResolver
        type ::Types::Ai::DuoSettings::DuoSettingsType, null: false

        def resolve
          return unless Ability.allowed?(current_user, :manage_self_hosted_models_settings)

          ::Ai::Setting.instance
        end
      end
    end
  end
end
