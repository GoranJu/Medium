# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirements::UpdateService,
  feature_category: :compliance_management do
  let_it_be_with_refind(:namespace) { create(:group) }
  let_it_be_with_refind(:framework) { create(:compliance_framework, namespace: namespace) }
  let_it_be_with_refind(:requirement) do
    create(:compliance_requirement, framework: framework, control_expression: old_control_expression)
  end

  let_it_be(:owner) { create(:user, owner_of: namespace) }
  let_it_be(:maintainer) { create(:user) }
  let_it_be(:developer) { create(:user) }
  let_it_be(:guest) { create(:user) }
  let_it_be(:non_member) { create(:user) }

  let(:params) { { description: 'New Description', name: 'New Name', control_expression: control_expression } }

  before_all do
    namespace.add_maintainer(maintainer)
    namespace.add_developer(developer)
    namespace.add_guest(guest)
  end

  shared_examples 'unsuccessful update' do |error_message|
    it 'does not update the compliance requirement' do
      expect { service.execute }.not_to change { requirement.reload.attributes }
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
      subject(:service) { described_class.new(requirement: requirement, current_user: owner, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is maintainer' do
      subject(:service) { described_class.new(requirement: requirement, current_user: maintainer, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is developer' do
      subject(:service) { described_class.new(requirement: requirement, current_user: developer, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is guest' do
      subject(:service) { described_class.new(requirement: requirement, current_user: guest, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is non-member' do
      subject(:service) { described_class.new(requirement: requirement, current_user: non_member, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end
  end

  context 'when feature is enabled' do
    before do
      stub_licensed_features(custom_compliance_frameworks: true)
      allow(::Gitlab::Audit::Auditor).to receive(:audit)
    end

    context 'when current user is namespace owner' do
      subject(:service) { described_class.new(requirement: requirement, current_user: owner, params: params) }

      context 'with valid params' do
        it 'updates the compliance requirement' do
          expect { service.execute }.to change { requirement.reload.name }.to('New Name')
                                                                          .and change {
                                                                            requirement.reload.description
                                                                          }.to('New Description')
                                                                           .and change {
                                                                             requirement.reload.control_expression
                                                                           }.to(control_expression)
        end

        it 'is successful' do
          result = service.execute

          expect(result.success?).to be true
          expect(result.payload[:requirement]).to eq(requirement)
        end

        it 'audits the changes' do
          old_values = {
            name: requirement.name,
            description: requirement.description,
            control_expression: requirement.control_expression
          }

          new_values = {
            name: 'New Name',
            description: 'New Description',
            control_expression: control_expression
          }

          service.execute

          expect(::Gitlab::Audit::Auditor).to have_received(:audit).exactly(3).times

          old_values.each do |attribute, old_value|
            expect(::Gitlab::Audit::Auditor).to have_received(:audit).with(
              name: 'update_compliance_requirement',
              author: owner,
              scope: requirement.framework.namespace,
              target: requirement,
              message: "Changed compliance requirement's #{attribute} from #{old_value} to #{new_values[attribute]}"
            )
          end
        end
      end

      context 'with invalid params' do
        let(:params) { { name: '', control_expression: 'invalid_json' } }

        it_behaves_like 'unsuccessful update', 'Failed to update compliance requirement'

        it 'returns validation errors' do
          result = service.execute

          expect(result.payload.full_messages).to include("Name can't be blank")
          expect(result.payload.full_messages).to include("Expression should be a valid json object.")
        end
      end
    end

    context 'when current user is maintainer' do
      subject(:service) { described_class.new(requirement: requirement, current_user: maintainer, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is developer' do
      subject(:service) { described_class.new(requirement: requirement, current_user: developer, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is guest' do
      subject(:service) { described_class.new(requirement: requirement, current_user: guest, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end

    context 'when current user is non-member' do
      subject(:service) { described_class.new(requirement: requirement, current_user: non_member, params: params) }

      it_behaves_like 'unsuccessful update', 'Not permitted to update requirement'
    end
  end

  def old_control_expression
    {
      operator: "=",
      field: "minimum_approvals_required",
      value: 2
    }.to_json
  end

  def control_expression
    {
      operator: "=",
      field: "minimum_approvals_required",
      value: 4
    }.to_json
  end
end
