# frozen_string_literal: true

module API
  class DuoCodeReview < ::API::Base
    include APIGuard

    feature_category :code_review_workflow

    allow_access_with_scope :ai_features

    before do
      not_found! unless Gitlab.dev_or_test_env?

      authenticate!

      license_feature_available = ::License.feature_available?(:ai_review_mr)
      global_feature_flag_enabled = Gitlab::Llm::Utils::FlagChecker.flag_enabled_for_feature?(:review_merge_request)
      feature_flag_enabled = ::Feature.enabled?(:ai_review_merge_request, current_user)

      not_found! unless license_feature_available && global_feature_flag_enabled && feature_flag_enabled
    end

    namespace 'duo_code_review' do
      resources :evaluations do
        params do
          requires :new_path, type: String, limit: 255, desc: 'New path of the diff file'
          requires :diff, type: String, desc: 'Diff for context'
          requires :hunk, type: String, desc: 'Hunk to be reviewed'
        end
        post do
          prompt = ::Gitlab::Llm::Templates::ReviewMergeRequest
            .new(declared_params[:new_path], declared_params[:diff], declared_params[:hunk])
            .to_prompt

          response = ::Gitlab::Llm::Anthropic::Client.new(
            current_user,
            unit_primitive: 'review_merge_request'
          ).messages_complete(**prompt)

          response_modifier = ::Gitlab::Llm::Anthropic::ResponseModifiers::ReviewMergeRequest.new(response)

          review_response = { review: response_modifier.response_body }

          present review_response, with: Grape::Presenters::Presenter
        end
      end
    end
  end
end
