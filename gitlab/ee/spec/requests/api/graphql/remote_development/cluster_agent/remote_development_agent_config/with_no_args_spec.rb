# frozen_string_literal: true

require 'spec_helper'
require_relative './shared'

# NOTE: Even though this `single remoteDevelopmentAgentConfig` spec only has no fields to test, we still use similar
#       shared examples patterns and structure as the other multi-model query specs, for consistency.

RSpec.describe 'Query.project.clusterAgent.remoteDevelopmentAgentConfig', feature_category: :workspaces do
  include_context 'for a Query.project.clusterAgent.remoteDevelopmentAgentConfig query'

  it_behaves_like 'single remoteDevelopmentAgentConfig query'
end
