# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SelfSigned::AccessDataReader, feature_category: :cloud_connector do
  describe '#read_available_services' do
    subject(:available_services) { described_class.new.read_available_services }

    it 'parses the service data correctly' do
      expect(available_services).to include({
        duo_chat: be_instance_of(CloudConnector::SelfSigned::AvailableServiceData)
      })
    end

    it 'configures AvailableServiceData objects correctly' do
      expect(available_services[:duo_chat].name).to eq(:duo_chat)
      expect(available_services[:duo_chat].cut_off_date).to eq(Time.zone.parse("2024-10-17T00:00:00Z"))
      expect(available_services[:duo_chat].add_on_names).to match_array(%w[code_suggestions duo_enterprise])
    end
  end
end
