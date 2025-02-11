# frozen_string_literal: true

module Ci
  module Minutes
    class UpdateBuildMinutesService < BaseService
      # Calculates consumption and updates the project and namespace statistics(legacy)
      # or ProjectMonthlyUsage and NamespaceMonthlyUsage(not legacy) based on the passed build.
      include Gitlab::InternalEventsTracking

      def execute(build)
        return unless build.complete?
        return unless build.duration&.positive?

        track_ci_build_minutes(build)

        return unless build.shared_runner_build?

        ci_minutes_consumed =
          ::Gitlab::Ci::Minutes::Consumption
            .new(pipeline: build.pipeline, runner_matcher: build.runner.runner_matcher, duration: build.duration)
            .amount

        update_usage(build, ci_minutes_consumed)
      end

      private

      def update_usage(build, ci_minutes_consumed)
        ::Ci::Minutes::UpdateProjectAndNamespaceUsageWorker
          .perform_async(ci_minutes_consumed, project.id, namespace.id, build.id, { duration: build.duration })
      end

      def namespace
        project.shared_runners_limit_namespace
      end

      def track_ci_build_minutes(build)
        track_internal_event(
          "track_ci_build_minutes_with_runner_type",
          namespace: namespace,
          additional_properties: {
            label: build.runner&.runner_type&.to_s,
            value: (build.duration / 60).round(2)
          }
        )
      end
    end
  end
end
