# frozen_string_literal: true

module EE
  module Gitlab
    module BackgroundMigration
      module BackfillFreeSharedRunnersMinutesLimit
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override

        prepended do
          operation_name :backfill_free_shared_runners_minutes_limit
          scope_to ->(relation) do
            relation.where(type: 'User', parent_id: nil)
          end
        end

        class Namespace < ::ApplicationRecord
          self.table_name = 'namespaces'
        end

        override :perform
        def perform
          each_sub_batch do |sub_batch|
            cte = ::Gitlab::SQL::CTE.new(:batched_relation, sub_batch.limit(100))

            # `hosted_plan_id`: 34 is the free tier plan on .com
            scope = cte.apply_to(Namespace.all)
              .joins(%(
                LEFT OUTER JOIN gitlab_subscriptions
                ON gitlab_subscriptions.namespace_id = namespaces.id
              ))
              .where.not(shared_runners_minutes_limit: nil)
              .where("gitlab_subscriptions.id IS NULL OR gitlab_subscriptions.hosted_plan_id = 34")

            Namespace.where(id: scope.select('namespaces.id')).update_all(shared_runners_minutes_limit: nil)
          end
        end
      end
    end
  end
end
