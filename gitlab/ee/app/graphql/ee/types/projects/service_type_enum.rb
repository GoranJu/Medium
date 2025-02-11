# frozen_string_literal: true

module EE
  module Types
    module Projects
      module ServiceTypeEnum
        extend ActiveSupport::Concern

        class_methods do
          extend ::Gitlab::Utils::Override

          private

          override :integration_names
          def integration_names
            Integration.available_integration_names(
              include_instance_specific: false,
              include_dev: false,
              include_disabled: true,
              include_blocked_by_settings: true
            )
          end
        end
      end
    end
  end
end
