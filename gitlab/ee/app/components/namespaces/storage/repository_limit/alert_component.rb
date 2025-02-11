# frozen_string_literal: true

module Namespaces
  module Storage
    module RepositoryLimit
      class AlertComponent < BaseAlertComponent
        HIGH_LIMIT_USAGE_THRESHOLDS = {
          none: 0,
          warning: 0.9,
          error: 1
        }.freeze

        private

        def render?
          return true if show_approaching_high_limit_message?
          return false if context.is_a?(Group) && !current_page?(group_usage_quotas_path(context))
          return false if context.is_a?(Project) && context.repository_size_excess == 0

          super
        end

        def alert_title
          if show_approaching_high_limit_message?
            safe_format(
              s_(
                "NamespaceStorageSize|We've noticed an unusually high storage usage on %{namespace_name}"
              ),
              { namespace_name: root_namespace.name }
            )
          else
            super
          end
        end

        def default_alert_title
          text_args = {
            readonly_project_count: root_namespace.repository_size_excess_project_count,
            namespace_name: root_namespace.name
          }

          ns_(
            "NamespaceStorageSize|%{namespace_name} has " \
              "%{readonly_project_count} read-only project",
            "NamespaceStorageSize|%{namespace_name} has " \
              "%{readonly_project_count} read-only projects",
            text_args[:readonly_project_count]
          ) % text_args
        end

        def usage_percentage_alert_title
          text_args = {
            usage_in_percent: used_storage_percentage(root_storage_size.usage_ratio),
            namespace_name: root_namespace.name
          }

          if root_storage_size.above_size_limit?
            default_alert_title
          else
            s_(
              "NamespaceStorageSize|You have used %{usage_in_percent} of the purchased storage for %{namespace_name}"
            ) % text_args
          end
        end

        def free_tier_alert_title
          text_args = {
            readonly_project_count: root_namespace.repository_size_excess_project_count,
            free_size_limit: formatted(limit)
          }

          if root_namespace.paid?
            default_alert_title
          else
            ns_(
              "NamespaceStorageSize|You have reached the free storage limit of %{free_size_limit} on " \
                "%{readonly_project_count} project",
              "NamespaceStorageSize|You have reached the free storage limit of %{free_size_limit} on " \
                "%{readonly_project_count} projects",
              text_args[:readonly_project_count]
            ) % text_args
          end
        end

        def alert_message
          manage_storage_link = help_page_path('user/storage_usage_quotas.md', anchor: 'manage-storage-usage')

          if show_approaching_high_limit_message?
            [
              safe_format(
                s_(
                  "NamespaceStorageSize|To manage your usage and prevent your projects " \
                    "from being placed in a read-only state, you should immediately " \
                    "%{manage_storage_link_start}reduce storage%{link_end}, or " \
                    "%{support_link_start}contact support%{link_end} to help you manage your usage."
                ),
                {
                  **tag_pair(link_to('', manage_storage_link), :manage_storage_link_start, :link_end),
                  **tag_pair(link_to('', "https://support.gitlab.com"), :support_link_start, :link_end)
                }
              )
            ]
          else
            super
          end
        end

        def alert_message_explanation
          text_args = {
            free_size_limit: formatted(limit),
            **tag_pair(link_to('', storage_docs_link), :storage_docs_link_start, :link_end)
          }

          if root_storage_size.above_size_limit?
            safe_format(
              s_(
                "NamespaceStorageSize|You have consumed all available " \
                  "%{storage_docs_link_start}storage%{link_end} and you can't " \
                  "push or add large files to projects over the free tier limit (%{free_size_limit})."
              ),
              text_args
            )
          else
            safe_format(
              s_(
                "NamespaceStorageSize|If a project reaches 100%% of the " \
                  "%{storage_docs_link_start}storage quota%{link_end} (%{free_size_limit}) the project will be " \
                  "in a read-only state, and you won't be able to push to your repository or add large files."
              ),
              text_args
            )
          end
        end

        def alert_message_cta
          group_member_link = group_group_members_path(root_namespace)
          purchase_more_link = help_page_path('subscriptions/gitlab_com/_index.md', anchor: 'purchase-more-storage')
          text_args = {
            **tag_pair(link_to('', group_member_link), :group_member_link_start, :link_end),
            **tag_pair(link_to('', purchase_more_link), :purchase_more_link_start, :link_end)
          }

          if root_storage_size.above_size_limit?
            if Ability.allowed?(user, :owner_access, context)
              return safe_format(
                s_(
                  "NamespaceStorageSize|To remove the read-only state, reduce git repository and git LFS storage, " \
                    "or %{purchase_more_link_start}purchase more storage%{link_end}."
                ),
                text_args
              )
            end

            safe_format(
              s_(
                "NamespaceStorageSize|To remove the read-only state, reduce git repository and git LFS storage, " \
                  "or contact a user with the %{group_member_link_start}owner role for this namespace%{link_end} " \
                  "and ask them to %{purchase_more_link_start}purchase more storage%{link_end}."
              ),
              text_args
            )
          else
            s_("NamespaceStorageSize|To reduce storage usage, reduce git repository and git LFS storage.")
          end
        end

        def usage_thresholds
          if show_approaching_high_limit_message?
            HIGH_LIMIT_USAGE_THRESHOLDS
          elsif namespace_has_additional_storage_purchased?
            DEFAULT_USAGE_THRESHOLDS
          else
            DEFAULT_USAGE_THRESHOLDS.except(:warning, :alert)
          end
        end

        def limit
          root_namespace.actual_size_limit
        end

        def usage_ratio
          if show_approaching_high_limit_message?
            included_storage_usage_ratio
          else
            super
          end
        end

        def included_storage_usage_ratio
          total_storage_limit = limit + root_namespace.additional_purchased_storage_size

          BigDecimal(root_namespace.total_repository_size) / BigDecimal(total_storage_limit)
        end

        def show_purchase_link?
          return false if root_namespace.actual_plan.paid_excluding_trials?

          super
        end

        def show_approaching_high_limit_message?
          return false unless root_storage_size.subject_to_high_limit?

          included_storage_usage_ratio >= HIGH_LIMIT_USAGE_THRESHOLDS[:warning] &&
            included_storage_usage_ratio < HIGH_LIMIT_USAGE_THRESHOLDS[:error]
        end
      end
    end
  end
end
