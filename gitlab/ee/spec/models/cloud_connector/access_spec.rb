# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Access, :models, feature_category: :cloud_connector do
  describe 'validations' do
    let_it_be(:cloud_connector_access) { create(:cloud_connector_access) }

    subject { cloud_connector_access }

    it { is_expected.to validate_presence_of(:data) }
  end
end
