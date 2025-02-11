# frozen_string_literal: true

module Ai
  class FeatureSetting < ApplicationRecord
    self.table_name = "ai_feature_settings"

    STABLE_FEATURES = {
      code_generations: 0,
      code_completions: 1,
      duo_chat: 2
    }.freeze

    FLAGGED_FEATURES = {
      duo_chat_explain_code: 3,
      duo_chat_write_tests: 4,
      duo_chat_refactor_code: 5,
      duo_chat_fix_code: 6
    }.freeze

    FEATURE_METADATA_PATH = Rails.root.join('ee/lib/gitlab/ai/feature_settings/feature_metadata.yml')
    FEATURE_METADATA = YAML.load_file(FEATURE_METADATA_PATH)

    FeatureMetadata = Struct.new(:title, :main_feature, :compatible_llms, :release_state, keyword_init: true)

    belongs_to :self_hosted_model, foreign_key: :ai_self_hosted_model_id, inverse_of: :feature_settings

    validates :self_hosted_model, presence: true, if: :self_hosted?
    validates :feature, presence: true, uniqueness: true
    validates :provider, presence: true

    validate :validate_model, if: :self_hosted?

    scope :find_or_initialize_by_feature, ->(feature) { find_or_initialize_by(feature: feature) }
    scope :for_self_hosted_model, ->(self_hosted_model_id) { where(ai_self_hosted_model_id: self_hosted_model_id) }

    enum provider: {
      disabled: 0,
      vendored: 1,
      self_hosted: 2
    }, _default: :vendored

    enum feature: STABLE_FEATURES.merge(FLAGGED_FEATURES)

    delegate :title, :main_feature, :compatible_llms, :release_state, to: :metadata, allow_nil: true

    def self.code_suggestions_self_hosted?
      exists?(feature: [:code_generations, :code_completions], provider: :self_hosted)
    end

    def self.provider_titles
      {
        disabled: s_('AdminAiPoweredFeatures|Disabled'),
        vendored: s_('AdminAiPoweredFeatures|AI vendor'),
        self_hosted: s_('AdminAiPoweredFeatures|Self-hosted model')
      }.with_indifferent_access.freeze
    end

    def self.allowed_features
      allowed_features = STABLE_FEATURES

      allowed_features = allowed_features.merge(FLAGGED_FEATURES) if Feature.enabled?(:ai_duo_chat_sub_features_settings) # rubocop:disable Gitlab/FeatureFlagWithoutActor -- The feature flag is global

      allowed_features.stringify_keys
    end

    def provider_title
      title = self.class.provider_titles[provider]
      return title unless self_hosted?

      "#{title} (#{self_hosted_model.name})"
    end

    def base_url
      return Gitlab::AiGateway.url if self_hosted?

      Gitlab::AiGateway.cloud_connector_url
    end

    def metadata
      feature_metadata = FEATURE_METADATA[feature.to_s] || {}

      FeatureMetadata.new(feature_metadata)
    end

    def compatible_self_hosted_models
      if compatible_llms.present?
        ::Ai::SelfHostedModel.where(model: compatible_llms)
      else
        ::Ai::SelfHostedModel.all
      end
    end

    def validate_model
      return unless compatible_llms.present?
      return unless self_hosted_model.present?

      selected_model = self_hosted_model.model

      return if compatible_llms.include?(selected_model)

      message = format(s_('AdminAiPoweredFeatures|%{selected_model} is incompatible with the %{title} feature'),
        selected_model: selected_model.capitalize,
        title: title)
      errors.add(:base, message)
    end
  end
end
