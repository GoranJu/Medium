# frozen_string_literal: true

# Handles enforcement for storage limit
#
# This class has the logic for repository size limits (a.k.a Project Enforcement Limits).
# Repository limits include repository size and LFS.
# Docs:
# - https://docs.gitlab.com/ee/administration/settings/account_and_limit_settings.html#repository-size-limit
# - https://docs.gitlab.com/ee/user/storage_usage_quotas.html
#
# Self-Managed customers can set this limit using the docs above.
# At GitLab.com an instance wide limit of 10 GiB per project is set. Some plans may have higher limits.
#
# At GitLab.com customers can purchase additional storage, which will be added to the root namespace and
# can be consumed by any project in the namespace hierarchy that is over the instance wide limit.
#
module Namespaces
  module Storage
    module RepositoryLimit
      class Enforcement
        include ::Gitlab::Utils::StrongMemoize

        attr_reader :root_namespace

        def initialize(root_namespace)
          @root_namespace = root_namespace.root_ancestor # just in case the true root isn't passed
        end

        def above_size_limit?
          return false unless enforce_limit?

          current_size > limit
        end

        def usage_ratio
          return 1 if limit == 0 && current_size > 0
          return 0 if limit == 0

          BigDecimal(current_size) / BigDecimal(limit)
        end

        def current_size
          root_namespace.total_repository_size_excess
        end
        strong_memoize_attr :current_size

        def exceeded_size(change_size = 0)
          exceeded_size = current_size + change_size - limit

          [exceeded_size, 0].max
        end

        def limit
          # https://docs.gitlab.com/ee/user/storage_usage_quotas#project-storage-limit
          root_namespace.additional_purchased_storage_size.megabytes
        end
        strong_memoize_attr :limit

        def enforce_limit?
          ::Gitlab::CurrentSettings.automatic_purchased_storage_allocation?
        end

        def subject_to_high_limit?
          return false unless Feature.enabled?(:plan_limits_repository_size, root_namespace)

          root_namespace.actual_plan.paid_excluding_trials?
        end

        def error_message
          message_params = { namespace_name: root_namespace.name }

          @error_message_object ||= ::Gitlab::RootExcessSizeErrorMessage.new(self, message_params)
        end

        def enforcement_type
          :project_repository_limit
        end
      end
    end
  end
end
