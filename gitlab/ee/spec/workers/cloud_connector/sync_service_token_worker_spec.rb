# frozen_string_literal: true

require 'spec_helper'

RSpec.describe CloudConnector::SyncServiceTokenWorker, type: :worker, feature_category: :cloud_connector do
  describe '#perform' do
    let(:service) { instance_double(CloudConnector::SyncCloudConnectorAccessService) }
    let(:service_response) { ServiceResponse.success }

    let_it_be(:license) { create(:license) }
    let(:job_args) { [{ license_id: license.id }] }

    before do
      allow_next_instance_of(CloudConnector::SyncCloudConnectorAccessService, license) do |service|
        allow(service).to receive(:execute).and_return(service_response)
      end
    end

    include_examples 'an idempotent worker' do
      let(:worker) { described_class.new }

      subject(:sync_service_token) { perform_multiple(job_args, worker: worker) }

      context 'when license ID is passed' do
        it 'executes the SyncCloudConnectorAccessService with given license' do
          expect(::License).not_to receive(:current)
          expect(worker).not_to receive(:log_extra_metadata_on_done)

          sync_service_token
        end
      end

      context 'when no license ID is passed' do
        let(:job_args) { [] }

        it 'executes the SyncCloudConnectorAccessService with current license' do
          expect(::License).to receive(:current).at_least(:once).and_return(license)
          expect(worker).not_to receive(:log_extra_metadata_on_done)

          sync_service_token
        end
      end

      context 'when SyncCloudConnectorAccessService fails' do
        let(:service_response) { ServiceResponse.error(message: 'Error') }

        it { expect { sync_service_token }.not_to raise_error }

        it 'logs the error' do
          expect(worker).to receive(:log_extra_metadata_on_done)
                              .with(:error_message, service_response[:message]).twice

          sync_service_token
        end
      end
    end
  end
end
