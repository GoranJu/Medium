# frozen_string_literal: true

module Types
  module Ai
    module FeatureSettings
      class FeaturesEnum < BaseEnum
        graphql_name 'AiFeatures'
        description 'AI features that can be configured in the settings.'

        # this method set the enum values for the allowed features settings.
        def self.set_features_enum_values
          ::Ai::FeatureSetting.allowed_features.each_key do |feature_key|
            feature_title = feature_key == :duo_chat ? feature_key.to_s.titleize : feature_key.to_s.humanize.singularize
            value feature_key.upcase, description: "#{feature_title} feature setting", value: feature_key
          end
        end

        set_features_enum_values
      end
    end
  end
end
