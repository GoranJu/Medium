# frozen_string_literal: true

module EE
  module Users
    module GroupCalloutsHelper
      ALL_SEATS_USED_ALERT = 'all_seats_used_alert'
      COMPLIANCE_FRAMEWORK_SETTINGS_MOVED_CALLOUT = 'compliance_framework_settings_moved_callout'

      def show_compliance_framework_settings_moved_callout?(group)
        !user_dismissed_for_group(COMPLIANCE_FRAMEWORK_SETTINGS_MOVED_CALLOUT, group)
      end
    end
  end
end
