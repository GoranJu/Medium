# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControls::UpdateService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be(:requirement) do
    create(:compliance_requirement, framework: create(:compliance_framework, namespace: namespace))
  end

  let_it_be(:control) { create(:compliance_requirements_control, compliance_requirement: requirement) }

  let_it_be(:owner) { create(:user, owner_of: namespace) }
  let_it_be(:maintainer) { create(:user) }

  let_it_be(:control_expression) do
    {
      operator: "=",
      field: "project_visibility",
      value: 'private'
    }.to_json
  end

  let_it_be(:old_control_expression) do
    {
      operator: "=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end

  let(:params) { { name: 'project_visibility_not_internal', expression: control_expression } }

  before_all do
    namespace.add_maintainer(maintainer)
  end

  subject(:service) { described_class.new(control: control, current_user: current_user, params: params) }

  shared_examples 'unsuccessful update' do |error_message|
    it 'does not update the compliance requirement control' do
      expect { service.execute }.not_to change { control.reload.attributes }
    end

    it 'is unsuccessful' do
      result = service.execute

      expect(result.success?).to be false
      expect(result.message).to eq _(error_message)
    end

    it 'does not audit the changes' do
      service.execute

      expect(::Gitlab::Audit::Auditor).not_to have_received(:audit)
    end
  end

  context 'when feature is disabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: false)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      let(:current_user) { owner }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement control'
    end

    context 'when current user is maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement control'
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      let(:current_user) { owner }

      context 'with valid params' do
        it 'audits the changes' do
          old_values = {
            name: 'minimum_approvals_required_2',
            expression: old_control_expression
          }

          new_values = {
            name: 'project_visibility_not_internal',
            expression: control_expression
          }

          result = service.execute

          old_values.each do |attribute, old_value|
            expected_event_hash = {
              name: 'updated_compliance_requirement_control',
              author: owner,
              scope: control.namespace,
              target: result.payload[:control],
              message: "Changed compliance requirement control's #{attribute} " \
                "from '#{old_value}' to '#{new_values[attribute]}'"
            }

            expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
              expected_event_hash
            )
          end
        end

        it 'updates the compliance requirement control' do
          expect { service.execute }.to change { control.reload.attributes.slice('name', 'expression') }
            .to({ 'name' => 'project_visibility_not_internal', 'expression' => control_expression })
        end

        it 'is successful' do
          result = service.execute

          expect(result.success?).to be true
          expect(result.payload[:control]).to eq(control)
        end
      end

      context 'with invalid params' do
        let(:params) { { name: 'invalid_name', expression: 'invalid_json' } }

        it_behaves_like 'unsuccessful update',
          "Failed to update compliance requirement control. Error: 'invalid_name' is not a valid name"
      end
    end

    context 'when current user is maintainer' do
      let(:current_user) { maintainer }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement control'
    end
  end
end
