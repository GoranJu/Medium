# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Query.group(fullPath).scanExecutionPolicies', feature_category: :security_policy_management do
  include GraphqlHelpers
  include_context 'with group level scan execution policies'

  let_it_be(:policy_configuration) do
    create(:security_orchestration_policy_configuration,
      security_policy_management_project: policy_management_project,
      project: nil, namespace: group)
  end

  subject(:query_result) { graphql_data_at(:group, :scanExecutionPolicies, :nodes) }

  context 'when policy_scope is present in the policy' do
    it 'returns the policy' do
      expect(query_result).to match_array([expected_policy_response(policy)])
    end
  end

  context 'when policy_scope is present in policy' do
    include_context 'with scan execution policy and policy_scope'

    it 'returns the policy' do
      expect(query_result).to match_array([expected_policy_response(policy).merge(expected_policy_scope_response)])
    end
  end
end
