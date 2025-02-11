# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::Keys, :models, feature_category: :cloud_connector do
  describe 'validations' do
    subject(:key_record) { create(:cloud_connector_keys) }

    it { is_expected.to be_valid }

    context 'when secret_key is nil' do
      before do
        key_record.secret_key = nil
      end

      it { is_expected.to be_valid }
    end

    context 'when secret_key is not a valid RSA key' do
      before do
        key_record.secret_key = ''
      end

      it { is_expected.not_to be_valid }
    end
  end
end
