# frozen_string_literal: true

module Llm
  module Internal
    class CompletionService < ::Llm::BaseService
      extend ::Gitlab::Utils::Override

      MAX_RUN_TIME = 30.seconds

      attr_reader :prompt_message, :options

      def initialize(prompt_message, options = {})
        @prompt_message = prompt_message
        @options = options
      end

      def execute
        return unless ai_action_enabled?(prompt_message)

        with_tracking(prompt_message.ai_action) do
          prompt_message.context.assign_attributes(resource: nil) unless resource_authorized?(prompt_message)

          options.symbolize_keys!
          options[:extra_resource] = ::Llm::ExtraResourceFinder
            .new(prompt_message.user, options.delete(:referer_url)).execute

          completion = ::Gitlab::Llm::CompletionsFactory.completion!(prompt_message, options)
          log_perform(prompt_message, completion.class.name)

          completion.execute
        end
      rescue StandardError => e
        Gitlab::ErrorTracking.track_and_raise_for_dev_exception(
          e, { user_id: prompt_message.user&.id, resource: prompt_message.resource&.to_gid }
        )
        nil
      end

      private

      def with_tracking(ai_action)
        start_time = options[:start_time] || ::Gitlab::Metrics::System.monotonic_time

        response = yield

        update_error_rate(ai_action, response)
        update_duration_metric(ai_action, ::Gitlab::Metrics::System.monotonic_time - start_time)

        response
      rescue StandardError => err
        update_error_rate(ai_action)
        raise err
      end

      def log_perform(prompt_message, completion_class_name)
        log_debug(
          message: "Performing CompletionService",
          event_name: 'completion_service_performed',
          ai_component: 'abstraction_layer',
          user_id: prompt_message.user.to_gid,
          resource_id: prompt_message.resource&.to_gid,
          action_name: prompt_message.ai_action.to_sym,
          request_id: prompt_message.request_id,
          client_subscription_id: prompt_message.client_subscription_id,
          completion_service_name: completion_class_name
        )
      end

      def resource_authorized?(prompt_message)
        !prompt_message.resource ||
          prompt_message.user.can?("read_#{prompt_message.resource.to_ability_name}", prompt_message.resource)
      end

      def update_error_rate(ai_action_name, response = nil)
        completion = ::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST[ai_action_name.to_sym]
        return unless completion

        success = response.try(:errors)&.empty?

        Gitlab::Metrics::Sli::ErrorRate[:llm_completion].increment(
          labels: {
            feature_category: completion[:feature_category],
            service_class: completion[:service_class].name
          },
          error: !success
        )
      end

      def update_duration_metric(ai_action_name, duration)
        completion = ::Gitlab::Llm::Utils::AiFeaturesCatalogue::LIST[ai_action_name.to_sym]
        return unless completion

        labels = {
          feature_category: completion[:feature_category],
          service_class: completion[:service_class].name
        }
        Gitlab::Metrics::Sli::Apdex[:llm_completion].increment(
          labels: labels,
          success: duration <= MAX_RUN_TIME
        )
      end

      def ai_action_enabled?(prompt_message)
        Gitlab::Llm::Utils::FlagChecker.flag_enabled_for_feature?(prompt_message.ai_action.to_sym)
      end
    end
  end
end
