# frozen_string_literal: true

module EE
  module Gitlab
    module ClickHouse
      extend ActiveSupport::Concern

      class_methods do
        def enabled_for_analytics?(_group = nil)
          globally_enabled_for_analytics?
        end

        def globally_enabled_for_analytics?
          configured? && ::Gitlab::CurrentSettings.current_application_settings.use_clickhouse_for_analytics?
        end
      end
    end
  end
end
