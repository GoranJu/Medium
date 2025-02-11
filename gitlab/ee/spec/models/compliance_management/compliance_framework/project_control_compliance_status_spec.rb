# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ProjectControlComplianceStatus, type: :model,
  feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:compliance_requirements_control) }
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to belong_to(:compliance_requirement) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:status) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:compliance_requirements_control) }

    describe 'uniqueness validation' do
      subject { build(:project_control_compliance_status) }

      it 'validates uniqueness of project id scoped to control id' do
        create(:project_control_compliance_status)
        is_expected.to validate_uniqueness_of(:project_id)
          .scoped_to(:compliance_requirements_control_id)
          .with_message('has already been taken')
      end
    end
  end

  describe 'enums' do
    it { is_expected.to define_enum_for(:status).with_values(pass: 0, fail: 1, pending: 2) }
  end

  describe 'factory' do
    it 'has a valid factory' do
      status = create(:project_control_compliance_status)
      expect(status).to be_valid
    end
  end

  describe '.for_project_and_control' do
    let_it_be(:project) { create(:project) }
    let_it_be(:another_project) { create(:project) }
    let_it_be(:control) { create(:compliance_requirements_control) }
    let_it_be(:another_control) { create(:compliance_requirements_control) }

    let_it_be(:status) do
      create(:project_control_compliance_status,
        project: project,
        compliance_requirements_control: control
      )
    end

    let_it_be(:another_project_status) do
      create(:project_control_compliance_status,
        project: another_project,
        compliance_requirements_control: control
      )
    end

    let_it_be(:another_control_status) do
      create(:project_control_compliance_status,
        project: project,
        compliance_requirements_control: another_control
      )
    end

    it 'returns records matching project_id and control_id' do
      result = described_class.for_project_and_control(project.id, control.id)

      expect(result).to contain_exactly(status)
    end

    it 'returns empty when no matching records exist' do
      result = described_class.for_project_and_control(non_existing_record_id, non_existing_record_id)

      expect(result).to be_empty
    end

    it 'does not return records for different project' do
      result = described_class.for_project_and_control(another_project.id, control.id)

      expect(result).not_to include(status)
      expect(result).to contain_exactly(another_project_status)
    end
  end
end
