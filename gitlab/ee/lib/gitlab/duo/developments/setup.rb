# frozen_string_literal: true

# rubocop:disable Gitlab/DocumentationLinks/HardcodedUrl -- Development purpose
module Gitlab
  module Duo
    module Developments
      class SelfManagedStrategy
        def execute
          puts <<~TXT.strip
          ================================================================================
          ## Running self-managed mode setup
          ## If you want to run .com mode, set GITLAB_SIMULATE_SAAS=1
          ================================================================================
          TXT

          require_self_managed!
        end

        private

        # rubocop:disable Style/GuardClause -- For reading simplicity
        def require_self_managed!
          if ::Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS'])
            raise <<~MSG
              Make sure 'GITLAB_SIMULATE_SAAS' environment variable is false or not set.
              See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance for more information.
            MSG
          end
        end
        # rubocop:enable Style/GuardClause
      end

      class GitlabComStrategy
        def initialize(namespace)
          @namespace = namespace
        end

        def execute
          puts <<~TXT.strip
          ================================================================================
          ## Running .com mode setup for group '#{@namespace}'
          ================================================================================
          TXT

          require_dot_com!
          ensure_application_settings!

          group = ensure_group
          ensure_group_subscription!(group)
          ensure_group_settings!(group)
          ensure_group_membership!(group)
        end

        private

        def require_dot_com!
          # rubocop:disable Style/GuardClause -- For reading simplicity
          unless ::Gitlab::Utils.to_boolean(ENV['GITLAB_SIMULATE_SAAS'])
            raise <<~MSG
              Make sure 'GITLAB_SIMULATE_SAAS' environment variable is truthy.
              See https://docs.gitlab.com/ee/development/ee_features.html#simulate-a-saas-instance for more information.
            MSG
          end
          # rubocop:enable Style/GuardClause
        end

        # rubocop:disable CodeReuse/ActiveRecord -- Development purpose
        def ensure_group_subscription!(group)
          puts "Activating an Ultimate license to the group...."

          plan = Plan.find_or_create_by(name: "ultimate", title: "Ultimate")

          GitlabSubscription.find_or_create_by(namespace: group, hosted_plan: plan).tap do |subscription|
            GitlabSubscription.where(namespace: group).update_all(hosted_plan_id: plan.id) if subscription.errors.any?
          end
        end
        # rubocop:enable CodeReuse/ActiveRecord

        def ensure_application_settings!
          puts "Enabling application settings...."

          Gitlab::CurrentSettings.current_application_settings
            .update!(check_namespace_plan: true, allow_local_requests_from_web_hooks_and_services: true)
        end

        def ensure_group
          puts "Checking the specified group exists...."

          raise "You must specify :root_group_path" unless @namespace.present?
          raise "Provided group name must be a root group" if @namespace.include?('/')

          group = Group.find_by_full_path(@namespace)

          if group
            puts "Found the group: #{group.name}"

            return group
          end

          puts "The specified group is not found. Creating a new one..."

          current_user = User.find_by_username('root')
          org = create_org(current_user)
          group_params = {
            name: @namespace,
            path: @namespace,
            organization: org,
            visibility_level: org.visibility_level
          }
          response = Groups::CreateService.new(current_user, group_params).execute
          group = response[:group]

          raise "Failed to create a group: #{group.errors.full_messages}" if response.error?

          group
        end

        def create_org(current_user)
          response = ::Organizations::CreateService.new(
            current_user: current_user,
            params: { name: @namespace, path: @namespace, visibility_level: ::Gitlab::VisibilityLevel::PUBLIC }
          ).execute
          org = response[:organization]

          raise "Failed to create an org: #{response.errors}" if response.error?

          org
        end

        def ensure_group_settings!(group)
          puts "Enabling the group settings...."

          group = Group.find(group.id) # Hard Reload for refreshing the cache
          group.update!(experiment_features_enabled: true)
        end

        def ensure_group_membership!(group)
          # this is needed because of the add-on creation - we need to make sure user is a member of a group.
          group.add_owner(User.find_by_username('root'))
        end
      end

      class Setup
        attr_reader :args

        def initialize(args)
          @args = args
          @namespace = args[:root_group_path]
          @setup_strategy = @namespace.present? ? GitlabComStrategy.new(@namespace) : SelfManagedStrategy.new
        end

        def execute
          ensure_dev_mode!
          ensure_feature_flags!
          ensure_license!
          @setup_strategy.execute
          create_add_on_purchases!

          print_result
        end

        private

        # rubocop:disable Style/GuardClause -- Keep it explicit
        def ensure_dev_mode!
          unless ::Gitlab.dev_or_test_env?
            raise <<~MSG
              Setup can only be performed in development or test environment, however, the current environment is #{ENV['RAILS_ENV']}.
            MSG
          end
        end
        # rubocop:enable Style/GuardClause

        def ensure_feature_flags!
          puts "Enabling feature flags...."

          Gitlab::Duo::Developments::FeatureFlagEnabler.execute
          ::Feature.enable(:summarize_my_code_review)
          ::Feature.enable(:enable_hamilton_in_user_preferences)
          ::Feature.enable(:allow_organization_creation)
        end

        def ensure_license!
          license = ::License.current
          raise 'No license found' unless license
        end

        def create_add_on_purchases!
          group = Group.find_by_full_path(@namespace) # will be nil for self-managed mode

          ::GitlabSubscriptions::AddOnPurchase.by_namespace(group).delete_all

          if args[:add_on] == 'duo_pro'
            create_duo_pro_purchase!(group)
          else
            create_enterprise_purchase!(group)
          end
        end

        def create_duo_pro_purchase!(group)
          add_on = ::GitlabSubscriptions::AddOn.find_or_create_by_name(:code_suggestions)

          response = ::GitlabSubscriptions::AddOnPurchases::CreateService.new(group, add_on, {
            quantity: 100,
            started_on: Time.current,
            expires_on: 1.year.from_now,
            purchase_xid: 'C-12345'
          }).execute

          raise response.message unless response.success?

          response.payload[:add_on_purchase].update!(users: [User.find_by_username('root')])

          puts "Code suggestions add-on added..."
        end

        def create_enterprise_purchase!(group)
          add_on = ::GitlabSubscriptions::AddOn.find_or_create_by_name(:duo_enterprise)

          response = ::GitlabSubscriptions::AddOnPurchases::CreateService.new(group, add_on, {
            quantity: 100,
            started_on: Time.current,
            expires_on: 1.year.from_now,
            purchase_xid: 'C-98766'
          }).execute

          raise response.message unless response.success?

          response.payload[:add_on_purchase].update!(users: [User.find_by_username('root')])
          puts "Duo enterprise add-on added..."
        end

        def print_result
          puts <<~MSG
            ----------------------------------------
            Setup Complete!
            ----------------------------------------

            Visit "#{Gitlab.config.gitlab.protocol}://#{Gitlab.config.gitlab.host}:#{Gitlab.config.gitlab.port}/#{@namespace.presence}" for testing GitLab Duo features.

            For more development guidelines, see https://docs.gitlab.com/ee/development/ai_features/.
          MSG

          Group.find_by_full_path(@namespace)
        end
      end
    end
  end
end
# rubocop:enable Gitlab/DocumentationLinks/HardcodedUrl
