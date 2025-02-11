# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::ComplianceFramework::ComplianceRequirement,
  type: :model, feature_category: :compliance_management do
  describe 'validations' do
    let_it_be(:group) { create(:group) }
    let_it_be(:compliance_framework) { create(:compliance_framework, namespace: group) }
    let_it_be(:requirement) { create(:compliance_requirement, framework: compliance_framework) }

    it { is_expected.to validate_uniqueness_of(:name).scoped_to(:framework_id) }
    it { is_expected.to validate_presence_of(:namespace_id) }
    it { is_expected.to validate_presence_of(:framework) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_presence_of(:description) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to validate_length_of(:control_expression).is_at_most(2048) }

    describe 'requirement_type' do
      it 'raises an ArgumentError for undefined requirement_type values' do
        expect do
          described_class.new(requirement_type: :undefined_type)
        end.to raise_error(ArgumentError, /'undefined_type' is not a valid requirement_type/)
      end
    end

    describe '#validate_internal_expression' do
      context 'when requirement_type is internal' do
        context 'when control expression is not a json' do
          let_it_be(:control_expression) { "non_json_string" }
          let_it_be(:requirement) do
            build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
              control_expression: control_expression)
          end

          it 'returns invalid json object error' do
            expect(requirement).to be_invalid
            expect(requirement.errors.full_messages).to contain_exactly('Expression should be a valid json object.')
          end
        end

        context 'when control expression is nil' do
          subject do
            build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
              control_expression: nil)
          end

          it { is_expected.to be_valid }
        end

        context 'when control expression is a json' do
          context 'when control expression is valid' do
            context 'when it is a simple expression' do
              let_it_be(:control_expression) do
                {
                  id: "minimum_approvals_required_2",
                  operator: "=",
                  field: "minimum_approvals_required",
                  value: 2
                }.to_json
              end

              subject do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it { is_expected.to be_valid }
            end

            context 'when less than 5 valid controls' do
              let_it_be(:control_expression) do
                {
                  operator: "AND",
                  conditions: [
                    {
                      id: "minimum_approvals_required_2",
                      operator: "=",
                      field: "minimum_approvals_required",
                      value: 2
                    },
                    {
                      id: "default_branch_protected",
                      operator: "=",
                      field: "default_branch_protected",
                      value: true
                    },
                    {
                      id: "project_visibility_internal",
                      operator: "=",
                      field: "project_visibility",
                      value: "internal"
                    }
                  ]
                }.to_json
              end

              subject do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it { is_expected.to be_valid }
            end

            context 'when there are exactly 5 valid controls' do
              let_it_be(:control_expression) do
                {
                  operator: "AND",
                  conditions: [
                    {
                      operator: "=",
                      field: "minimum_approvals_required",
                      value: 2
                    },
                    {
                      operator: "=",
                      field: "default_branch_protected",
                      value: true
                    },
                    {
                      operator: "=",
                      field: "scanner_sast_running",
                      value: true
                    },
                    {
                      operator: "=",
                      field: "project_visibility",
                      value: "private"
                    },
                    {
                      operator: "=",
                      field: "merge_request_prevent_author_approval",
                      value: false
                    }
                  ]
                }.to_json
              end

              subject do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it { is_expected.to be_valid }
            end
          end

          context 'when control expression is invalid' do
            context 'when controls are less than 5 but one is invalid' do
              let_it_be(:control_expression) do
                {
                  operator: "AND",
                  conditions: [
                    {
                      operator: "=",
                      field: "minimum_approvals_required",
                      value: 2
                    },
                    {
                      operator: "=",
                      field: "default_branch_protected",
                      value: "something"
                    },
                    {
                      operator: "=",
                      field: "scanner_sast_running",
                      value: true
                    }
                  ]
                }.to_json
              end

              let_it_be(:requirement) do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it 'returns invalid expression error' do
                expect(requirement).to be_invalid
                expect(requirement.errors.full_messages)
                  .to include("Expression property '/conditions/1/value' is not of type: boolean")
              end
            end

            context 'when controls are valid but more than 5' do
              let_it_be(:control_expression) do
                {
                  operator: "AND",
                  conditions: [
                    {
                      operator: "=",
                      field: "minimum_approvals_required",
                      value: 2
                    },
                    {
                      operator: "=",
                      field: "default_branch_protected",
                      value: true
                    },
                    {
                      operator: "=",
                      field: "scanner_sast_running",
                      value: true
                    },
                    {
                      operator: "=",
                      field: "project_visibility",
                      value: "private"
                    },
                    {
                      operator: "=",
                      field: "merge_request_prevent_author_approval",
                      value: false
                    },
                    {
                      operator: "=",
                      field: "merge_request_prevent_committers_approval",
                      value: false
                    }
                  ]
                }.to_json
              end

              let_it_be(:requirement) do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it 'returns invalid expression error for maxItems' do
                expect(requirement).to be_invalid
                expect(requirement.errors.full_messages)
                  .to include("Expression property '/conditions' is invalid: error_type=maxItems")
              end
            end

            context 'when OR operator is used' do
              let_it_be(:control_expression) do
                {
                  operator: "OR",
                  conditions: [
                    {
                      operator: "=",
                      field: "minimum_approvals_required",
                      value: 2
                    },
                    {
                      operator: "=",
                      field: "default_branch_protected",
                      value: true
                    },
                    {
                      operator: "=",
                      field: "project_visibility",
                      value: "private"
                    }
                  ]
                }.to_json
              end

              let_it_be(:requirement) do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it 'returns invalid operator error in expression' do
                expect(requirement).to be_invalid
                expect(requirement.errors.full_messages)
                  .to include("Expression property '/operator' is not one of: [\"AND\"]")
              end
            end

            context 'when there is nesting in controls' do
              let_it_be(:control_expression) do
                {
                  operator: "AND",
                  conditions: [
                    {
                      operator: "=",
                      field: "minimum_approvals_required",
                      value: 2
                    },
                    {
                      operator: "=",
                      field: "default_branch_protected",
                      value: true
                    },
                    {
                      operator: "=",
                      field: "project_visibility",
                      value: "internal"
                    },
                    {
                      operator: "AND",
                      conditions: [
                        {
                          operator: "=",
                          field: "merge_request_prevent_author_approval",
                          value: false
                        },
                        {
                          operator: "=",
                          field: "scanner_sast_running",
                          value: false
                        }
                      ]
                    }
                  ]
                }.to_json
              end

              let_it_be(:requirement) do
                build(:compliance_requirement, name: 'Test requirement', framework: compliance_framework,
                  control_expression: control_expression)
              end

              it 'returns invalid operator error' do
                expect(requirement).to be_invalid
                expect(requirement.errors.full_messages)
                  .to include("Expression property '/conditions/3/operator' is not one of: [\"=\"]")
              end
            end
          end
        end
      end
    end

    describe '#requirements_count_per_framework' do
      let_it_be(:compliance_framework_1) { create(:compliance_framework, :sox, namespace: group) }

      subject(:new_compliance_requirement) { build(:compliance_requirement, framework: compliance_framework_1) }

      context 'when requirements count is one less than max count' do
        before do
          49.times do |i|
            create(:compliance_requirement, framework: compliance_framework_1, name: "Test#{i}")
          end
        end

        it 'creates requirement with no error' do
          expect(new_compliance_requirement.valid?).to eq(true)
          expect(new_compliance_requirement.errors).to be_empty
        end
      end

      context 'when requirements count is equal to max count' do
        before do
          50.times do |i|
            create(:compliance_requirement, framework: compliance_framework_1, name: "Test#{i}")
          end
        end

        it 'returns error' do
          expect(new_compliance_requirement.valid?).to eq(false)
          expect(new_compliance_requirement.errors.full_messages)
            .to contain_exactly("Framework cannot have more than 50 requirements")
        end
      end
    end
  end

  describe "associations" do
    it { is_expected.to belong_to(:framework).optional(false) }
    it { is_expected.to belong_to(:namespace).optional(false) }
    it { is_expected.to have_many(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_framework_security_policies).through(:security_policy_requirements) }
    it { is_expected.to have_many(:compliance_requirements_controls) }
    it { is_expected.to have_many(:project_control_compliance_statuses) }
  end
end
