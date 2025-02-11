# frozen_string_literal: true

module Ai
  module AdditionalContext
    CODE_SUGGESTIONS_CONTEXT_TYPES = { file: 'file', snippet: 'snippet' }.freeze

    # Unlike Duo Chat, Code Suggestions additional context categories are NOT connected to unit primitives
    # The Code Suggestions unit primitives are `complete_code` and `generate_code`
    # The Code Suggestions additional context categories are simply controlled through Feature Flags
    CODE_SUGGESTIONS_CONTEXT_CATEGORIES = [
      :repository_xray,
      :open_tabs,
      :imports
    ].freeze

    # Introducing new types requires adding `include_*_context` unit primitives as well.
    #
    # First, decide whether a unit primitive is part of Duo Pro or Duo Enterprise.
    # Then, follow the examples of `include_*_context` unit primitives:
    # https://gitlab.com/gitlab-org/gitlab/-/blob/ddbd15c27268963f72e77beb4797d41e8e918f94/ee/config/cloud_connector/access_data.yml
    # https://gitlab.com/gitlab-org/customers-gitlab-com/-/blob/3d1dbc421cca5ca86e8577213660b063f71bf27b/config/cloud_connector.yml
    #
    # The unit primitives need to be added to both the `gitlab-org/gitlab` and `gitlab-org/customers-gitlab-com`
    # repositories.
    DUO_CHAT_CONTEXT_CATEGORIES = {
      file: 'file',
      snippet: 'snippet',
      merge_request: 'merge_request',
      issue: 'issue',
      dependency: 'dependency',
      local_git: 'local_git'
    }.freeze

    MAX_BODY_SIZE = ::API::CodeSuggestions::MAX_BODY_SIZE
    MAX_CONTEXT_TYPE_SIZE = 255
  end
end
