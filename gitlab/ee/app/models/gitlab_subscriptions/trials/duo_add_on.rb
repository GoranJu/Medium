# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    module DuoAddOn
      extend ::GitlabSubscriptions::SubscriptionHelper

      def self.any_add_on_purchased_or_trial?(namespace)
        add_on_purchase = if gitlab_com_subscription?
                            GitlabSubscriptions::Duo.any_add_on_purchase_for_namespace(namespace)
                          else
                            # for non SaaS environments we need to look for add-on purchase related to
                            # self managed instance
                            GitlabSubscriptions::Duo.any_add_on_purchase_for_namespace(nil)
                          end

        return false unless add_on_purchase.present?

        if add_on_purchase.trial?
          GitlabSubscriptions::Trials::AddOnStatus.new(add_on_purchase: add_on_purchase).show?
        else
          add_on_purchase.active?
        end
      end
    end
  end
end
