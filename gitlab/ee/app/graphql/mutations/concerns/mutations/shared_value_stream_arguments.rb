# frozen_string_literal: true

module Mutations
  module SharedValueStreamArguments
    extend ActiveSupport::Concern

    included do
      argument :stages, [Types::Analytics::CycleAnalytics::ValueStreams::StageInputType],
        required: false,
        description: 'Value stream custom stages.'

      argument :setting,
        Types::Analytics::CycleAnalytics::ValueStreams::SettingInputType,
        required: false,
        description: 'Value stream configuration.'
    end
  end
end
