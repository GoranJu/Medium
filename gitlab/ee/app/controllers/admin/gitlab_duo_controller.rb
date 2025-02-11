# frozen_string_literal: true

# EE:Self Managed
module Admin
  class GitlabDuoController < Admin::ApplicationController
    include ::GitlabSubscriptions::CodeSuggestionsHelper

    respond_to :html

    feature_category :ai_abstraction_layer
    urgency :low

    before_action :ensure_feature_available!

    before_action do
      push_frontend_feature_flag(:enable_add_on_users_filtering)
    end

    def show; end

    private

    def ensure_feature_available!
      render_404 if Gitlab.com? # rubocop:disable Gitlab/AvoidGitlabInstanceChecks -- Not related to SaaS offerings
      render_404 unless License.current&.paid?
    end
  end
end
