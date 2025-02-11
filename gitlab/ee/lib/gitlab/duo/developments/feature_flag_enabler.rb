# frozen_string_literal: true

module Gitlab
  module Duo
    module Developments
      class FeatureFlagEnabler
        def self.execute
          feature_flag_names = Feature::Definition.definitions.filter_map do |k, v|
            k if v.group == 'group::ai framework'
          end

          feature_flag_names.flatten.each do |ff|
            puts "Enabling the feature flag: #{ff}"
            Feature.enable(ff.to_sym)
          end
        end
      end
    end
  end
end
