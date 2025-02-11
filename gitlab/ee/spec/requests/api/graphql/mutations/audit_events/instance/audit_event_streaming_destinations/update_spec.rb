# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Update instance level external audit event destination', feature_category: :audit_events do
  include GraphqlHelpers

  let_it_be_with_reload(:destination) { create(:audit_events_instance_external_streaming_destination) }
  let_it_be(:current_user) { create(:admin) }
  let_it_be(:updated_config) do
    {
      "accessKeyXid" => 'AKIA1234RANDOM5678',
      "bucketName" => 'test-rspec-bucket',
      "awsRegion" => 'us-east-2'
    }
  end

  let_it_be(:updated_secret_token) { 'TEST/SECRET/XYZ/PQR' }
  let_it_be(:updated_category) { 'aws' }
  let_it_be(:updated_destination_name) { 'updated_destination_name' }
  let_it_be(:destination_gid) { global_id_of(destination) }

  let(:mutation) { graphql_mutation(:instance_audit_event_streaming_destinations_update, input) }
  let(:mutation_response) { graphql_mutation_response(:instance_audit_event_streaming_destinations_update) }

  let(:input) do
    {
      id: destination_gid,
      config: updated_config,
      name: updated_destination_name,
      category: updated_category,
      secret_token: updated_secret_token
    }
  end

  subject(:mutate) { post_graphql_mutation(mutation, current_user: current_user) }

  shared_examples 'a mutation that does not update the instance destination' do
    it 'does not update the destination' do
      expect { mutate }.not_to change { destination.reload.attributes }
    end

    it 'does not create audit event' do
      expect { mutate }.not_to change { AuditEvent.count }
    end
  end

  context 'when feature is licensed' do
    before do
      stub_licensed_features(external_audit_events: true)
      stub_feature_flags(audit_events_external_destination_streamer_consolidation_refactor: false)
    end

    context 'when current user is instance admin' do
      before do
        allow(Gitlab::Audit::Auditor).to receive(:audit)
      end

      it 'updates the destination' do
        mutate

        destination.reload

        expect(destination.config).to eq(updated_config)
        expect(destination.name).to eq(updated_destination_name)
        expect(destination.category).to eq(updated_category)
        expect(destination.secret_token).to eq(updated_secret_token)
      end

      it 'audits the update' do
        Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update::AUDIT_EVENT_COLUMNS.each do |column|
          message = if column == :secret_token
                      "Changed #{column}"
                    else
                      "Changed #{column} from #{destination[column]} to #{input[column.to_s.camelize(:lower).to_sym]}"
                    end

          expected_hash = {
            name: Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update::UPDATE_EVENT_NAME,
            author: current_user,
            scope: an_instance_of(Gitlab::Audit::InstanceScope),
            target: destination,
            message: message
          }

          expect(Gitlab::Audit::Auditor).to receive(:audit).once.ordered.with(hash_including(expected_hash))
        end

        mutate
      end

      context 'when the fields are updated with existing values' do
        let(:input) do
          {
            id: destination_gid,
            config: destination.config,
            name: destination.name
          }
        end

        it 'does not audit the event' do
          expect(Gitlab::Audit::Auditor).not_to receive(:audit)

          mutate
        end
      end

      context 'when no fields are provided for update' do
        let(:input) do
          {
            id: destination_gid
          }
        end

        it_behaves_like 'a mutation that does not update the instance destination'
      end

      context 'when there is error while updating' do
        before do
          allow_next_instance_of(
            Mutations::AuditEvents::Instance::AuditEventStreamingDestinations::Update) do |mutation|
            allow(mutation).to receive(:authorized_find!).with(id: destination_gid).and_return(destination)
          end

          allow(destination).to receive(:update).and_return(false)

          errors = ActiveModel::Errors.new(destination).tap { |e| e.add(:base, 'error message') }
          allow(destination).to receive(:errors).and_return(errors)
        end

        it 'does not update the destinationuration and returns the error' do
          mutate

          expect(mutation_response).to include(
            'externalAuditEventDestination' => nil,
            'errors' => ['error message']
          )
        end
      end

      context 'when destination is updated' do
        let(:legacy_destination) { create(:instance_amazon_s3_configuration, stream_destination_id: destination.id) }

        it_behaves_like 'updates a legacy destination', :destination,
          proc {
            {
              legacy: {
                bucket_name: updated_config["bucketName"],
                aws_region: updated_config["awsRegion"],
                access_key_xid: updated_config["accessKeyXid"],
                name: updated_destination_name
              },
              streaming: {
                "accessKeyXid" => updated_config["accessKeyXid"],
                "bucketName" => updated_config["bucketName"],
                "awsRegion" => updated_config["awsRegion"],
                "name" => updated_destination_name
              }
            }
          }
      end
    end

    context 'when current user is not instance admin' do
      let_it_be(:current_user) { create(:user) }

      it_behaves_like 'a mutation on an unauthorized resource'
      it_behaves_like 'a mutation that does not update the instance destination'
    end
  end

  context 'when feature is unlicensed' do
    before do
      stub_licensed_features(external_audit_events: false)
    end

    it_behaves_like 'a mutation on an unauthorized resource'
    it_behaves_like 'a mutation that does not update the instance destination'
  end
end
