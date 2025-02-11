# frozen_string_literal: true

module GitlabSubscriptions
  module AddOnPurchases
    module SelfManaged
      module ProvisionServices
        class Base
          extend ::Gitlab::Utils::Override
          include ::Gitlab::Utils::StrongMemoize

          AddOnPurchaseSyncError = Class.new(StandardError)
          MethodNotImplementedError = Class.new(StandardError)

          def execute
            result = license_has_add_on? ? create_or_update_add_on_purchase : expire_prior_add_on_purchase
            return result if result.success?

            error = AddOnPurchaseSyncError.new(
              "Error syncing subscription add-on purchases. Message: #{result[:message]}"
            )

            Gitlab::ErrorTracking.track_and_raise_for_dev_exception(error)
            ServiceResponse.error(message: error.message)
          end

          private

          def license_has_add_on?
            !!current_license&.cloud_license? && quantity.to_i > 0
          end

          def current_license
            License.current
          end
          strong_memoize_attr :current_license

          def license_restrictions
            current_license&.license&.restrictions
          end

          def empty_success_response
            ServiceResponse.success(payload: { add_on_purchase: nil })
          end

          def create_or_update_add_on_purchase
            service_class = if add_on_purchase
                              GitlabSubscriptions::AddOnPurchases::UpdateService
                            else
                              GitlabSubscriptions::AddOnPurchases::CreateService
                            end

            service_class.new(namespace, add_on, attributes).execute
          end

          def add_on_purchase
            raise MethodNotImplementedError
          end

          def add_on
            raise MethodNotImplementedError
          end

          def namespace
            nil # self-managed is unrelated to namespaces
          end

          def attributes
            {
              add_on_purchase: add_on_purchase,
              started_on: starts_at,
              expires_on: expires_on,
              purchase_xid: purchase_xid,
              quantity: quantity,
              trial: trial?
            }
          end

          def expire_prior_add_on_purchase
            return empty_success_response unless add_on_purchase

            GitlabSubscriptions::AddOnPurchases::SelfManaged::ExpireService.new(add_on_purchase).execute
          end

          def quantity
            raise MethodNotImplementedError
          end

          # The naming of this attribute is different in multiple places:
          # It's called `started_on` within the license's add-ons (original name) but `started_at` in the GitLab
          # code (due to feedback in a database review). It also uses past tense but we're going to offer support
          # for future dated add-ons. Since this method is the provisioning method, it uses `starts_at` (present
          # tense) to try to indicate a possible future start.
          def starts_at
            raise MethodNotImplementedError
          end

          def expires_on
            raise MethodNotImplementedError
          end

          def purchase_xid
            raise MethodNotImplementedError
          end

          def trial?
            raise MethodNotImplementedError
          end
        end
      end
    end
  end
end
