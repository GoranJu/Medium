# frozen_string_literal: true

module Security
  module SecurityOrchestrationPolicies
    module ComplianceFrameworks
      class SyncService
        def initialize(configuration)
          @configuration = configuration
        end

        def execute
          container = configuration.source
          framework_ids_with_policy_index = configuration.compliance_framework_ids_with_policy_index
          framework_ids = framework_ids_with_policy_index.flat_map { |ids_with_idx| ids_with_idx[:framework_ids] }.uniq

          root_namespace = container.root_ancestor
          frameworks_count = root_namespace.compliance_management_frameworks.id_in(framework_ids).count

          if frameworks_count != framework_ids.count
            Gitlab::AppJsonLogger.info(
              message: 'inaccessible compliance_framework_ids found in policy',
              configuration_id: configuration.id,
              configuration_source_id: container.id,
              root_namespace_id: root_namespace.id,
              policy_framework_ids: framework_ids,
              inaccessible_framework_ids_count: (framework_ids.count - frameworks_count)
            )

            return
          end

          framework_policy_attrs = framework_ids_with_policy_index.flat_map do |ids_with_idx|
            ids_with_idx[:framework_ids].map do |framework_id|
              {
                framework_id: framework_id,
                policy_configuration_id: configuration.id,
                policy_index: ids_with_idx[:policy_index]
              }
            end
          end

          ComplianceManagement::ComplianceFramework::SecurityPolicy.relink(configuration, framework_policy_attrs)
        end

        private

        attr_reader :configuration
      end
    end
  end
end
