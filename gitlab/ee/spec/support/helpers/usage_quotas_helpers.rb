# frozen_string_literal: true

module UsageQuotasHelpers
  include NamespacesHelper

  def buy_minutes_subscriptions_link(group)
    buy_additional_minutes_path(group)
  end
end

UsageQuotasHelpers.prepend_mod
