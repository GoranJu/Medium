# frozen_string_literal: true

module Mutations
  module Ai
    module FeatureSettings
      class Update < Base
        graphql_name 'AiFeatureSettingUpdate'
        description "Updates or create setting for the AI feature."

        argument :feature, ::Types::Ai::FeatureSettings::FeaturesEnum,
          required: true,
          description: 'AI feature being configured.'

        argument :provider, ::Types::Ai::FeatureSettings::ProvidersEnum,
          required: true,
          description: 'Provider for AI setting.'

        argument :ai_self_hosted_model_id,
          ::Types::GlobalIDType[::Ai::SelfHostedModel],
          required: false,
          description: 'Global ID of the self-hosted model provide the AI setting.'

        def resolve(**args)
          check_feature_access!

          result = upsert_feature_setting(args)

          if result.error?
            {
              ai_feature_setting: nil,
              errors: Array(result.errors)
            }
          else
            { ai_feature_setting: result.payload, errors: [] }
          end
        end

        private

        def upsert_feature_setting(args)
          feature_setting = find_or_initialize_object(feature: args[:feature])
          feature_settings_params = args.dup

          self_hosted_model_gid = feature_settings_params[:ai_self_hosted_model_id]

          if self_hosted_model_gid.present?
            feature_settings_params[:ai_self_hosted_model_id] = GitlabSchema.parse_gid(self_hosted_model_gid)&.model_id
          end

          ::Ai::FeatureSettings::UpdateService.new(
            feature_setting, current_user, feature_settings_params
          ).execute
        end

        def find_or_initialize_object(feature:)
          ::Ai::FeatureSetting.find_or_initialize_by_feature(feature)
        end
      end
    end
  end
end
