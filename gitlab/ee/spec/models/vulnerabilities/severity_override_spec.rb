# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::SeverityOverride, feature_category: :vulnerability_management do
  it { is_expected.to define_enum_for(:new_severity) }
  it { is_expected.to define_enum_for(:original_severity) }

  describe 'associations' do
    it { is_expected.to belong_to(:author).class_name('User').inverse_of(:vulnerability_severity_overrides) }
    it { is_expected.to belong_to(:vulnerability).class_name('Vulnerability').inverse_of(:severity_overrides) }
    it { is_expected.to belong_to(:project).required(true) }
  end

  describe 'validations' do
    let_it_be(:severity_override) { create(:vulnerability_severity_override, new_severity: :high) }

    it { is_expected.to validate_presence_of(:vulnerability) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:original_severity) }
    it { is_expected.to validate_presence_of(:new_severity) }
    it { is_expected.to validate_presence_of(:author).on(:create) }

    it "is expected to validate that original and new severities differ" do
      severity_override.original_severity = severity_override.new_severity

      expect(severity_override).to be_invalid
      expect { severity_override.save! }.to raise_error(ActiveRecord::RecordInvalid,
        'Validation failed: New severity must not be the same as original severity')
    end

    context 'when attribute values are valid' do
      let_it_be(:project) { create(:project) }
      let_it_be(:vulnerability) { create(:vulnerability, project: project) }
      let_it_be(:user) { create(:user) }
      let_it_be(:severity_overrides) do
        [
          build(:vulnerability_severity_override,
            vulnerability: vulnerability,
            project: project,
            author: user,
            original_severity: :low,
            new_severity: :critical
          )
        ]
      end

      subject { build(:vulnerability, severity_overrides: severity_overrides) }

      it { is_expected.to be_valid }
    end
  end

  context 'with loose foreign key on vulnerability_severity_overrides.author_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:user) }
      let_it_be(:model) { create(:vulnerability_severity_override, author: parent) }
    end
  end

  context 'with loose foreign key on vulnerability_severity_overrides.project_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:project) }
      let_it_be(:model) { create(:vulnerability_severity_override, project_id: parent.id) }
    end
  end
end
