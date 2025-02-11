# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update a compliance requirement', feature_category: :compliance_management do
  include GraphqlHelpers

  let_it_be(:namespace) { create(:group) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: framework, control_expression: old_control_expression)
  end

  let_it_be(:owner) { create(:user) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }

  let(:mutation) do
    graphql_mutation(:update_compliance_requirement, { id: global_id_of(requirement), **mutation_params })
  end

  let(:mutation_params) do
    {
      params: {
        name: 'New Name',
        description: 'New Description',
        control_expression: control_expression
      }
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  def mutation_response
    graphql_mutation_response(:update_compliance_requirement)
  end

  shared_examples 'a mutation that updates a compliance requirement' do
    it 'updates the requirement' do
      expect { mutate }.to change { requirement.reload.name }.to('New Name')
                                                             .and change {
                                                               requirement.reload.description
                                                             }.to('New Description')
                                                              .and change {
                                                                requirement.reload.control_expression
                                                              }.to(control_expression)
    end

    it 'returns the updated requirement', :aggregate_failures do
      mutate

      expect(mutation_response['requirement']['name']).to eq 'New Name'
      expect(mutation_response['requirement']['description']).to eq 'New Description'
      expect(mutation_response['requirement']['controlExpression']).to eq control_expression
    end

    it 'returns an empty array of errors' do
      mutate

      expect(mutation_response['errors']).to be_empty
    end
  end

  shared_examples 'a mutation that returns unauthorized error' do
    it 'does not update the compliance requirement' do
      expect { mutate }.not_to change { requirement.reload.attributes }
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
  end

  context 'when framework feature is unlicensed' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it_behaves_like 'a mutation that returns top-level errors',
      errors: [Gitlab::Graphql::Authorize::AuthorizeResource::RESOURCE_ACCESS_ERROR]
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    before_all do
      namespace.add_owner(owner)
      namespace.add_maintainer(maintainer)
      namespace.add_developer(developer)
      namespace.add_guest(guest)
    end

    context 'when current_user is group owner' do
      let(:current_user) { owner }

      it_behaves_like 'a mutation that updates a compliance requirement'

      context 'with invalid params' do
        let(:mutation_params) do
          {
            params: {
              name: '',
              description: ''
            }
          }
        end

        it 'returns an array of errors' do
          mutate

          expect(mutation_response['errors']).to contain_exactly "Description can't be blank", "Name can't be blank"
        end

        it 'does not update the requirement' do
          expect { mutate }.to not_change { requirement.reload.attributes }
        end
      end
    end

    context 'when current_user is a maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'a mutation that returns unauthorized error'
    end

    context 'when current_user is a developer' do
      let(:current_user) { developer }

      it_behaves_like 'a mutation that returns unauthorized error'
    end

    context 'when current_user is a guest' do
      let(:current_user) { guest }

      it_behaves_like 'a mutation that returns unauthorized error'
    end
  end

  def control_expression
    {
      operator: "=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end

  def old_control_expression
    {
      operator: "=",
      field: "minimum_approvals_required",
      value: 4
    }.to_json
  end
end
