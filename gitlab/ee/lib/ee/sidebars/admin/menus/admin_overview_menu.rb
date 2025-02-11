# frozen_string_literal: true

module EE
  module Sidebars
    module Admin
      module Menus
        module AdminOverviewMenu
          extend ::Gitlab::Utils::Override

          RESTRICTED_ADMIN_PERMISSIONS = {
            read_admin_dashboard: :dashboard_menu_item,
            read_admin_users: :users_menu_item
          }.freeze

          override :render?
          def render?
            super || restricted_administrator?
          end

          override :configure_menu_items
          def configure_menu_items
            return super if administrator?

            RESTRICTED_ADMIN_PERMISSIONS.each_pair do |permission, name|
              add_item(build_menu_item(name)) if can?(context.current_user, permission)
            end
          end

          private

          def build_menu_item(name)
            method(name).call
          end

          def administrator?
            can?(current_user, :admin_all_resources)
          end

          def restricted_administrator?
            can_any?(current_user, RESTRICTED_ADMIN_PERMISSIONS.keys)
          end
        end
      end
    end
  end
end
