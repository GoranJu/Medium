# frozen_string_literal: true

module GitlabSubscriptions
  module Duo
    def self.enterprise_or_pro_for_namespace(namespace)
      # If both add-on types are present, prioritize Enterprise over Pro. This is for cases where, for example,
      # a namespace has purchased a Duo Pro add-on but simultaneously has a Duo Enterprise add-on trial.
      duo_enterprise_add_on_purchase = GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(
        namespace,
        add_on: :duo_enterprise,
        only_active: false
      ).execute.first

      duo_enterprise_add_on_purchase || GitlabSubscriptions::NamespaceAddOnPurchasesFinder.new(
        namespace,
        add_on: :duo_pro,
        only_active: false
      ).execute.first
    end

    def self.no_add_on_purchase_for_namespace?(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo, only_active: false).execute.none?
    end

    def self.any_add_on_purchase_for_namespace(namespace)
      GitlabSubscriptions::NamespaceAddOnPurchasesFinder
        .new(namespace, add_on: :duo, only_active: false).execute.first
    end
  end
end
