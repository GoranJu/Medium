# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Create a Compliance Requirement', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:current_user) { create(:user) }

  let(:mutation) do
    graphql_mutation(
      :create_compliance_requirement,
      compliance_framework_id: framework.to_gid,
      params: {
        name: 'Custom framework requirement',
        description: 'Example Description',
        control_expression: control_expression
      }
    )
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:create_compliance_requirement)
  end

  shared_examples 'a mutation that creates a compliance requirement' do
    it 'creates a new compliance requirement' do
      expect { mutate }.to change { framework.compliance_requirements.count }.by 1
    end

    it 'returns the newly created requirement', :aggregate_failures do
      mutate

      expect(mutation_response['requirement']['name']).to eq 'Custom framework requirement'
      expect(mutation_response['requirement']['description']).to eq 'Example Description'
      expect(mutation_response['requirement']['controlExpression']).to eq control_expression
    end
  end

  context 'when framework feature is unlicensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      post_graphql_mutation(mutation, current_user: current_user)
    end

    it_behaves_like 'a mutation that returns a top-level access error'
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    context 'when current_user is group owner' do
      before_all do
        namespace.add_owner(current_user)
      end

      it_behaves_like 'a mutation that creates a compliance requirement'
    end

    context 'when current_user is not a group owner' do
      context 'when current_user is group owner' do
        before_all do
          namespace.add_maintainer(current_user)
        end

        it 'does not create a new compliance requirement' do
          expect { mutate }.not_to change { framework.compliance_requirements.count }
        end

        it_behaves_like 'a mutation that returns a top-level access error'
      end
    end
  end

  def control_expression
    {
      operator: "=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end
end
