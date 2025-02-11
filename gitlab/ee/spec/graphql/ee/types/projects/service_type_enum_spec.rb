# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['ServiceType'], feature_category: :integrations do
  it 'includes services that are blocked by settings' do
    stub_application_setting(allow_all_integrations: false)
    stub_licensed_features(integrations_allow_list: true)

    # As the enum values have been set when the class loaded, before the settings
    # were stubbed above, test indirectly by comparing with `.integration_names`.
    types = described_class.send(:integration_names).map do |name|
      Integration.integration_name_to_type(name)
    end

    expect(types).to match_array(described_class.values.values.map(&:value))
    expect(Integrations::Asana).to be_blocked_by_settings
    expect(types).to include('Integrations::Asana')
  end
end
