# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ComplianceManagement::Framework, :models, feature_category: :compliance_management do
  describe 'associations' do
    it { is_expected.to belong_to(:namespace) }
    it { is_expected.to have_many(:projects).through(:project_settings) }

    it {
      is_expected.to have_many(:project_settings)
        .class_name('ComplianceManagement::ComplianceFramework::ProjectSettings')
    }

    it {
      is_expected.to have_many(:compliance_framework_security_policies)
          .class_name('ComplianceManagement::ComplianceFramework::SecurityPolicy')
    }

    it {
      is_expected.to have_many(:security_orchestration_policy_configurations)
        .class_name('Security::OrchestrationPolicyConfiguration').through(:compliance_framework_security_policies)
    }

    it {
      is_expected.to have_many(:compliance_requirements)
        .class_name('ComplianceManagement::ComplianceFramework::ComplianceRequirement')
    }
  end

  describe 'validations' do
    let_it_be(:framework) { create(:compliance_framework) }

    subject { framework }

    it { is_expected.to validate_uniqueness_of(:namespace_id).scoped_to(:name) }
    it { is_expected.to validate_presence_of(:name) }
    it { is_expected.to validate_length_of(:name).is_at_most(255) }
    it { is_expected.to validate_length_of(:description).is_at_most(255) }
    it { is_expected.to validate_length_of(:color).is_at_most(10) }
    it { is_expected.to validate_length_of(:pipeline_configuration_full_path).is_at_most(255) }

    describe 'namespace_is_root_level_group' do
      context 'when namespace is a root group' do
        let_it_be(:namespace) { create(:group) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is valid' do
          expect(framework).to be_valid
        end
      end

      context 'when namespace is a user namespace' do
        let_it_be(:namespace) { create(:user_namespace) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is invalid' do
          expect(framework).not_to be_valid
          expect(framework.errors[:namespace]).to include('must be a group, user namespaces are not supported.')
        end
      end

      context 'when namespace is a subgroup' do
        let_it_be(:namespace) { create(:group, :nested) }
        let_it_be(:framework) { build(:compliance_framework, namespace: namespace) }

        it 'is invalid' do
          expect(framework).not_to be_valid
          expect(framework.errors[:namespace]).to include('must be a root group.')
        end
      end
    end
  end

  describe '#security_orchestration_policy_configurations' do
    let_it_be(:framework) { create(:compliance_framework) }

    context 'when the framework has many same policy configuration with different index' do
      let_it_be(:policy_configuration) { create(:security_orchestration_policy_configuration) }

      let_it_be(:compliance_framework_security_policy1) do
        create(:compliance_framework_security_policy, framework: framework,
          policy_configuration: policy_configuration, policy_index: 0)
      end

      let_it_be(:compliance_framework_security_policy2) do
        create(:compliance_framework_security_policy, framework: framework,
          policy_configuration: policy_configuration, policy_index: 1)
      end

      it 'returns distinct policy configurations' do
        expect(framework.security_orchestration_policy_configurations).to match_array([policy_configuration])
      end
    end
  end

  describe 'color' do
    context 'with whitespace' do
      subject { create(:compliance_framework, color: ' #ABC123 ') }

      it 'strips whitespace' do
        expect(subject.color).to eq('#ABC123')
      end
    end
  end

  describe '.search' do
    let_it_be(:framework) { create(:compliance_framework, name: 'some framework name') }
    let_it_be(:framework2) { create(:compliance_framework, name: 'another framework') }

    it 'returns frameworks with a matching name' do
      expect(described_class.search(framework.name)).to eq([framework])
    end

    it 'returns frameworks with a partially matching name' do
      expect(described_class.search(framework.name[0..2])).to eq([framework])
    end

    it 'returns frameworks with a matching name regardless of the casing' do
      expect(described_class.search(framework.name.upcase)).to eq([framework])
    end

    it 'returns multiple frameworks matching with name' do
      expect(described_class.search('rame')).to match_array([framework, framework2])
    end

    it 'returns all frameworks if search string is empty' do
      expect(described_class.search('')).to match_array([framework, framework2])
    end
  end

  describe 'scopes' do
    let_it_be(:project) { create(:project) }
    let_it_be(:namespace) { create(:group) }

    describe '.with_projects' do
      before do
        create(:compliance_framework_project_setting, :first_framework, project: project)
        create(:compliance_framework_project_setting, :second_framework, project: project)
      end

      it 'returns frameworks associated with given project ids in order of addition' do
        frameworks = described_class.with_projects([project.id])

        expect(frameworks.map(&:name)).to eq(['First Framework', 'Second Framework'])
      end
    end

    describe '.ordered_by_addition_time_and_pipeline_existence' do
      before do
        create(:compliance_framework_project_setting, :first_framework, project: project)
        create(:compliance_framework_project_setting, :second_framework, project: project)
        create(:compliance_framework_project_setting, :third_framework, project: project)
        create(:compliance_framework_project_setting,
          compliance_management_framework: create(:compliance_framework,
            pipeline_configuration_full_path: 'path/to/pipeline',
            name: 'Framework with pipeline'),
          project: project, created_at: 5.days.ago
        )
      end

      it 'left joins the table correctly' do
        sql = described_class.ordered_by_addition_time_and_pipeline_existence.to_sql

        expect(sql).to include('LEFT OUTER JOIN "project_compliance_framework_settings')
      end

      it 'returns frameworks in order of their addition time' do
        ordered_frameworks = described_class.ordered_by_addition_time_and_pipeline_existence

        expect(ordered_frameworks.pluck(:name)).to eq(['Framework with pipeline', 'First Framework',
          'Second Framework', 'Third Framework'])
      end
    end
  end
end
