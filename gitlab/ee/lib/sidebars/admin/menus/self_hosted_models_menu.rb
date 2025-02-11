# frozen_string_literal: true

module Sidebars
  module Admin
    module Menus
      class SelfHostedModelsMenu < ::Sidebars::Admin::BaseMenu
        override :link
        def link
          admin_ai_self_hosted_models_path
        end

        override :title
        def title
          s_('Admin|Self-hosted models')
        end

        override :sprite_icon
        def sprite_icon
          'machine-learning'
        end

        override :active_routes
        def active_routes
          { controller: :self_hosted_models }
        end
      end
    end
  end
end
