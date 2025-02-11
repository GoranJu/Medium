# frozen_string_literal: true

module ResolvesOrchestrationPolicy
  extend ActiveSupport::Concern
  include ConstructSecurityPolicies

  included do
    include Gitlab::Graphql::Authorize::AuthorizeResource

    calls_gitaly!

    alias_method :project, :object
  end
end
