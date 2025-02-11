# frozen_string_literal: true

module EE
  module Projects
    module Security
      module ConfigurationPresenter
        extend ::Gitlab::Utils::Override

        private

        override :container_scanning_for_registry_enabled
        def container_scanning_for_registry_enabled
          project_settings&.container_scanning_for_registry_enabled
        end

        override :secret_push_protection_enabled
        def secret_push_protection_enabled
          project_settings&.secret_push_protection_enabled
        end

        override :features
        def features
          super << scan(:container_scanning_for_registry, configured: container_scanning_for_registry_enabled)
        end

        override :secret_detection_configuration_path
        def secret_detection_configuration_path
          project_security_configuration_secret_detection_path(project)
        end
      end
    end
  end
end
