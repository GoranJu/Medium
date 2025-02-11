# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Mutations::ComplianceManagement::ComplianceFramework::ComplianceRequirements::Update,
  feature_category: :compliance_management do
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

  let(:mutation) { described_class.new(object: nil, context: query_context, field: nil) }
  let(:params) do
    {
      name: 'New Name',
      description: 'New Description',
      control_expression: control_expression
    }
  end

  before_all do
    namespace.add_owner(owner)
    namespace.add_maintainer(maintainer)
    namespace.add_developer(developer)
    namespace.add_guest(guest)
  end

  subject(:mutate) { mutation.resolve(id: global_id_of(requirement), params: params) }

  context 'when feature is licensed' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true, evaluate_group_level_compliance_pipeline: true)
    end

    context 'when parameters are valid' do
      context 'when current_user is an owner' do
        let(:current_user) { owner }

        it 'updates the requirement' do
          expect { mutate }.to change { requirement.reload.name }.to('New Name')
                                                                 .and change {
                                                                   requirement.reload.description
                                                                 }.to('New Description')
                                                                  .and change {
                                                                    requirement.reload.control_expression
                                                                  }.to(control_expression)
        end

        it 'returns the updated object' do
          response = mutate[:requirement]

          expect(response.name).to eq('New Name')
          expect(response.description).to eq('New Description')
          expect(response.control_expression).to eq(control_expression)
        end

        it 'returns no errors' do
          expect(mutate[:errors]).to be_empty
        end
      end

      context 'when current_user is a maintainer' do
        let(:current_user) { maintainer }

        it 'raises an error' do
          expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when current_user is a developer' do
        let(:current_user) { developer }

        it 'raises an error' do
          expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end

      context 'when current_user is a guest' do
        let(:current_user) { guest }

        it 'raises an error' do
          expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
        end
      end
    end

    context 'when parameters are invalid' do
      let(:current_user) { owner }
      let(:params) do
        {
          name: '',
          description: ''
        }
      end

      it 'does not change the requirement attributes' do
        expect { mutate }.to not_change { requirement.reload.attributes }
      end

      it 'returns validation errors' do
        expect(mutate[:errors]).to contain_exactly("Name can't be blank", "Description can't be blank")
      end
    end
  end

  context 'when feature is unlicensed' do
    let(:current_user) { owner }

    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    it 'raises an error' do
      expect { mutate }.to raise_error(Gitlab::Graphql::Errors::ResourceNotAvailable)
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
