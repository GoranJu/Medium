# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module ProvisionServices
        class Duo < Base
          LICENSE_ADD_ONS_ORDERED_BY_PRECEDENCE = [
            LicenseAddOns::DuoEnterprise,
            LicenseAddOns::DuoPro
          ].freeze

          private

          override :add_on
          override :quantity
          override :starts_at
          override :expires_on
          override :purchase_xid
          delegate :add_on, :quantity, :starts_at, :expires_on, :purchase_xid, to: :license_add_on, allow_nil: true

          override :add_on_purchase
          def add_on_purchase
            GitlabSubscriptions::AddOnPurchase.find_by_namespace_and_add_on(
              namespace,
              license_add_ons.map(&:add_on)
            )
          end
          strong_memoize_attr :add_on_purchase

          override :trial?
          def trial?
            !!license_add_on&.trial?
          end

          def license_add_ons
            LICENSE_ADD_ONS_ORDERED_BY_PRECEDENCE.map { |license_add_on| license_add_on.new(license_restrictions) }
          end
          strong_memoize_attr :license_add_ons

          def license_add_on
            license_add_ons.find(&:active?)
          end
          strong_memoize_attr :license_add_on
        end
      end
    end
  end
end
