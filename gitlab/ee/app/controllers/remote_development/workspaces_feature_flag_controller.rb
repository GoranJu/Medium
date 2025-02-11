# frozen_string_literal: true

module RemoteDevelopment
  # This controller exists because the actor for the feature flag is determined on the client side
  # based on what choices a user makes on the page. As such, we cannot rely on the normal approach
  # of passing the flag's state in the original body of the page, rather we would need to query
  # it in realtime based on the current selected actor. In this case, it is the namespace.
  # TODO: this will be cleaned up as part of gitlab-org/gitlab#482814+
  class WorkspacesFeatureFlagController < ApplicationController
    feature_category :workspaces
    urgency :low

    ALLOWED_FLAGS = [].freeze

    def show
      flag = permitted_params[:flag]

      return render json: { enabled: false } unless ALLOWED_FLAGS.include?(flag.to_s)

      namespace_id = permitted_params[:namespace_id]
      namespace = ::Namespace.find_by_id(namespace_id)

      return render json: { enabled: false } unless namespace

      begin
        render json: { enabled: Feature.enabled?(flag.to_sym, namespace.root_ancestor) }
      rescue Feature::InvalidFeatureFlagError
        render json: { enabled: false }
      end
    end

    private

    def permitted_params
      params.permit(:flag, :namespace_id)
    end
  end
end
