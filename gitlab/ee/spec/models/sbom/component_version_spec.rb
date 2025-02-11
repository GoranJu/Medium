# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Sbom::ComponentVersion, type: :model, feature_category: :dependency_management do
  describe 'associations' do
    it { is_expected.to belong_to(:component).required }
    it { is_expected.to have_many(:occurrences) }
    it { is_expected.to belong_to(:organization) }
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:version) }
    it { is_expected.to validate_length_of(:version).is_at_most(255) }
  end

  describe '.by_component_id_and_version' do
    let_it_be(:matching_version) { create(:sbom_component_version) }
    let_it_be(:non_matching_version) { create(:sbom_component_version) }

    subject(:results) do
      described_class.by_component_id_and_version(matching_version.component_id, matching_version.version)
    end

    it 'returns only the matching version' do
      expect(results.to_a).to eq([matching_version])
    end
  end

  context 'with loose foreign key on sbom_component_versions.organization_id' do
    it_behaves_like 'cleanup by a loose foreign key' do
      let_it_be(:parent) { create(:organization) }
      let_it_be(:model) { create(:sbom_component_version, organization: parent) }
    end
  end
end
