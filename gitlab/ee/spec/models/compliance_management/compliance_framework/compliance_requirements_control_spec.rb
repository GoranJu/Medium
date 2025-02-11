# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirementsControl,
  type: :model, feature_category: :compliance_management do
  let_it_be(:control) { create(:compliance_requirements_control) }

  describe 'associations' do
    it 'belongs to requirement' do
      is_expected.to belong_to(:compliance_requirement)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirement').required
    end

    it { is_expected.to belong_to(:namespace).optional(false) }
    it { is_expected.to have_many(:project_control_compliance_statuses) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:namespace) }
    it { is_expected.to validate_presence_of(:compliance_requirement) }
    it { is_expected.to validate_presence_of(:control_type) }

    it 'validates uniqueness of name scoped to requirement' do
      is_expected.to validate_uniqueness_of(:name)
         .scoped_to([:compliance_requirement_id]).ignoring_case_sensitivity
    end

    it { is_expected.to validate_length_of(:expression).is_at_most(255) }
  end

  describe 'enums' do
    it 'name has correct values' do
      is_expected.to define_enum_for(:name).with_values(
        scanner_sast_running: 0,
        minimum_approvals_required_2: 1,
        merge_request_prevent_author_approval: 2,
        merge_request_prevent_committers_approval: 3,
        project_visibility_not_internal: 4,
        default_branch_protected: 5,
        external_control: 10000
      )
    end

    it { is_expected.to define_enum_for(:control_type).with_values(internal: 0, external: 1) }
  end

  describe '#controls_count_per_requirement' do
    let_it_be(:compliance_requirement_1) { create(:compliance_requirement) }

    subject(:new_control) { build(:compliance_requirements_control, compliance_requirement: compliance_requirement_1) }

    context 'when controls count is one less than max count' do
      before do
        names = %w[
          scanner_sast_running
          merge_request_prevent_author_approval
          merge_request_prevent_committers_approval
          project_visibility_not_internal
        ]

        4.times do |i|
          create(:compliance_requirements_control, compliance_requirement: compliance_requirement_1, name: names[i])
        end
      end

      it 'creates control with no error' do
        expect(new_control.valid?).to be(true)
        expect(new_control.errors).to be_empty
      end
    end

    context 'when requirements count is equal to max count' do
      before do
        names = %w[
          scanner_sast_running
          merge_request_prevent_author_approval
          merge_request_prevent_committers_approval
          project_visibility_not_internal
          default_branch_protected
        ]

        5.times do |i|
          create(:compliance_requirements_control, compliance_requirement: compliance_requirement_1, name: names[i])
        end
      end

      it 'returns error' do
        expect(new_control.valid?).to be(false)
        expect(new_control.errors.full_messages)
          .to contain_exactly("Compliance requirement cannot have more than 5 controls")
      end
    end
  end

  describe 'external_url validation' do
    let_it_be(:compliance_requirement) { create :compliance_requirement }
    let(:control) do
      build :compliance_requirements_control,
        name: 'scanner_sast_running',
        compliance_requirement: compliance_requirement,
        control_type: control_type,
        secret_token: 'psssst'
    end

    context 'with external control type' do
      let(:control_type) { :external }

      it 'validates presence' do
        control.external_url = nil
        expect(control).not_to be_valid

        control.external_url = 'udp://example.com:1701'
        expect(control).not_to be_valid

        control.external_url = 'https://example.com/bar'
        expect(control).to be_valid

        control.external_url = 'https://localhost:1337/bar'
        expect(control).to be_valid
      end
    end

    context 'with internal control_type' do
      let(:control_type) { :internal }

      it 'ignores presence' do
        control.external_url = nil
        expect(control).to be_valid

        control.external_url = ' '
        expect(control).to be_valid
      end
    end
  end

  describe 'secret_token validation' do
    let_it_be(:compliance_requirement) { create :compliance_requirement }
    let(:control) do
      build :compliance_requirements_control,
        name: 'scanner_sast_running',
        compliance_requirement: compliance_requirement,
        control_type: control_type,
        external_url: FFaker::Internet.unique.http_url
    end

    context 'with external control type' do
      let(:control_type) { :external }

      it 'validates presence' do
        control.secret_token = nil
        expect(control).not_to be_valid

        control.secret_token = 'foo'
        expect(control).to be_valid
      end
    end

    context 'with internal control_type' do
      let(:control_type) { :internal }

      it 'ignores presence' do
        control.secret_token = nil
        expect(control).to be_valid

        control.secret_token = 'foo'
        expect(control).to be_valid
      end
    end
  end

  describe '#validate_internal_expression' do
    let_it_be(:compliance_requirement) { create(:compliance_requirement) }

    context 'when the expression is not a json' do
      let_it_be(:expression) { "non_json_string" }
      let_it_be(:control) do
        build(:compliance_requirements_control, name: 'scanner_sast_running',
          compliance_requirement: compliance_requirement, expression: expression)
      end

      it 'returns invalid json object error' do
        expect(control).to be_invalid
        expect(control.errors.full_messages).to contain_exactly('Expression should be a valid json object.')
      end
    end

    context 'when the expression is a json' do
      context 'when control expression is valid' do
        let_it_be(:expression) do
          {
            operator: "=",
            field: "minimum_approvals_required",
            value: 2
          }.to_json
        end

        subject do
          build(:compliance_requirements_control, name: 'minimum_approvals_required_2',
            compliance_requirement: compliance_requirement, expression: expression)
        end

        it { is_expected.to be_valid }
      end

      context 'when control expression is invalid' do
        let_it_be(:expression) do
          {
            operator: "=",
            field: "minimum_approvals_required",
            value: "invalid_value"
          }.to_json
        end

        subject(:control) do
          build(:compliance_requirements_control, name: 'minimum_approvals_required_2',
            compliance_requirement: compliance_requirement, expression: expression)
        end

        it 'returns invalid expression error' do
          expect(control).to be_invalid
          expect(control.errors.full_messages)
            .to include("Expression property '/value' is not of type: number")
        end
      end
    end
  end
end
