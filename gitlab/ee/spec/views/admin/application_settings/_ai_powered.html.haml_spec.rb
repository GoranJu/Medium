# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'admin/application_settings/_ai_powered', :with_cloud_connector, feature_category: :ai_abstraction_layer do
  let_it_be(:application_setting) { build(:application_setting) }
  let(:code_suggestions_service) { instance_double(CloudConnector::AvailableServices) }

  before do
    assign(:application_setting, application_setting)
    allow(CloudConnector::AvailableServices)
      .to receive(:find_by_name).with(:code_suggestions).and_return(code_suggestions_service)
    allow(CloudConnector::AvailableServices)
      .to receive_message_chain(:find_by_name, :purchased?).and_return(true)
  end

  context 'when duo chat is available' do
    it 'renders the settings app root' do
      render

      expect(rendered).to have_selector('#js-ai-settings')
    end
  end
end
