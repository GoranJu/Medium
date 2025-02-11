# frozen_string_literal: true

module CodeSuggestions
  module ModelDetails
    class CodeCompletion < Base
      FEATURE_SETTING_NAME = 'code_completions'

      def initialize(current_user:)
        super(current_user: current_user, feature_setting_name: FEATURE_SETTING_NAME)
      end

      def current_model
        # if self-hosted, the model details are provided by the client
        return {} if self_hosted?

        return fireworks_qwen_2_5_model_details if use_fireworks_qwen_for_code_completions?

        # the default behavior is returning an empty hash
        # AI Gateway will fall back to the code-gecko model if model details are not provided
        {}
      end

      def saas_primary_model_class
        return if self_hosted?

        return CodeSuggestions::Prompts::CodeCompletion::FireworksQwen if use_fireworks_qwen_for_code_completions?

        CodeSuggestions::Prompts::CodeCompletion::VertexAi
      end

      private

      def fireworks_qwen_2_5_model_details
        {
          model_provider: CodeSuggestions::Prompts::CodeCompletion::FireworksQwen::MODEL_PROVIDER,
          model_name: CodeSuggestions::Prompts::CodeCompletion::FireworksQwen::MODEL_NAME
        }
      end

      # We introduced an ops FF to allow organizations to opt out of Fireworks/Qwen.
      # On GitLab SaaS, Duo access is managed by top-level group,
      #   so we are checking the FF by the user's top-level group
      # On GitLab self-managed, Duo access is managed on an instance level;
      #   while we can check the FF on the instance level, we will follow
      #   FF development recommendations and check by the user actor
      def use_fireworks_qwen_for_code_completions?
        # check the beta FF against the current user and immediately return false if disabled
        return false if Feature.disabled?(:fireworks_qwen_code_completion, current_user, type: :beta)

        # if the beta FF is enabled, proceed to check the ops FF

        # on saas, check the user's groups
        return all_user_groups_opted_in_to_fireworks_qwen? if Gitlab.org_or_com? # rubocop: disable Gitlab/AvoidGitlabInstanceChecks -- see comment above method definition

        # on self-managed, check the ops FF against the entire instance
        instance_opted_in_to_fireworks_qwen?
      end

      def all_user_groups_opted_in_to_fireworks_qwen?
        # while this has potential to be expensive in terms of Feature Flag checking,
        #   we are expecting that for most if not all users, only 1 group is providing them the Duo Access
        #   so `user_duo_groups` should only return 1 group, and we are only checking the FF once
        user_duo_groups.none? do |group|
          Feature.enabled?(:code_completion_model_opt_out_from_fireworks_qwen, group, type: :ops)
        end
      end

      def instance_opted_in_to_fireworks_qwen?
        Feature.disabled?(:code_completion_model_opt_out_from_fireworks_qwen, :instance, type: :ops)
      end

      # fetches all the top-level groups that give the user Duo Access
      #   - the User#duo_available_namespace_ids method queries the `subscription_user_add_on_assignments`
      #     by user_id and filters to active gitlab duo pro and enterprise add-ons
      #   - the `subscription_user_add_on_assignments` has a `subscription_add_on_purchases`, which has a `namespace_id`
      #   - `subscription_add_on_purchases.namespace_id` is:
      #     - always set on SaaS (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/123778)
      #     - and not set on self-managed (https://gitlab.com/gitlab-org/gitlab/-/merge_requests/128899)
      def user_duo_groups
        @user_duo_groups ||= Group.by_id(current_user.duo_available_namespace_ids)
      end
    end
  end
end
