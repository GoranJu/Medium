# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::CreateService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:current_user) { create(:user, owner_of: namespace) }
  let_it_be(:framework) { create(:compliance_framework, namespace: namespace) }

  let(:params) do
    {
      name: 'Custom framework requirement',
      description: 'Description about the requirement',
      control_expression: control_expression
    }
  end

  context 'when custom_compliance_frameworks is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
    end

    subject(:requirement_creator) do
      described_class.new(framework: framework, params: params, current_user: current_user)
    end

    it 'does not create a new compliance requirement' do
      expect { requirement_creator.execute }.not_to change { framework.compliance_requirements.count }
    end

    it 'responds with an error message' do
      expect(requirement_creator.execute.message).to eq('Not permitted to create requirement')
    end
  end

  context 'when custom_compliance_frameworks is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
    end

    context 'when using invalid parameters' do
      subject(:requirement_creator) do
        described_class.new(framework: framework, params: params.except(:name), current_user: current_user)
      end

      let(:response) { requirement_creator.execute }

      it 'responds with an error service response' do
        expect(response.success?).to be_falsey
        expect(response.payload.messages[:name]).to contain_exactly "can't be blank"
      end
    end

    context 'when creating a compliance requirement for a namespace that current_user is not the owner of' do
      subject(:requirement_creator) do
        described_class.new(framework: framework, params: params, current_user: create(:user))
      end

      it 'responds with an error service response' do
        expect(requirement_creator.execute.success?).to be false
      end

      it 'does not create a new compliance requirement' do
        expect { requirement_creator.execute }.not_to change { framework.compliance_requirements.count }
      end
    end

    context 'when using parameters for a valid compliance requirement' do
      subject(:requirement_creator) do
        described_class.new(framework: framework, params: params, current_user: current_user)
      end

      it 'audits the changes' do
        expect { requirement_creator.execute }
          .to change { AuditEvent.where("details LIKE ?", "%created_compliance_requirement%").count }.by(1)
      end

      it 'creates a new compliance requirement' do
        expect { requirement_creator.execute }.to change { framework.compliance_requirements.count }.by(1)
      end

      it 'responds with a successful service response' do
        expect(requirement_creator.execute.success?).to be true
      end

      it 'has the expected attributes' do
        requirement = requirement_creator.execute.payload[:requirement]

        expect(requirement.attributes).to include(
          "name" => "Custom framework requirement",
          "description" => "Description about the requirement",
          "framework_id" => framework.id,
          "namespace_id" => namespace.id,
          "control_expression" => control_expression
        )
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
