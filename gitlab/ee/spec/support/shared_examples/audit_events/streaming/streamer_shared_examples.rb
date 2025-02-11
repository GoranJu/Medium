# frozen_string_literal: true

RSpec.shared_examples 'streamer streaming audit events' do |scope|
  let_it_be(:group) { create(:group) if scope == :group }
  let_it_be(:audit_event) do
    scope == :group ? create(:audit_event, :group_event, target_group: group) : create(:audit_event, :instance_event)
  end

  let(:event_type) { 'event_type ' }
  let(:streamer) { described_class.new(event_type, audit_event) }

  describe '#streamable?' do
    subject(:check_streamable) { streamer.streamable? }

    context 'when audit events licensed feature is false' do
      before do
        if scope == :group
          allow(audit_event.root_group_entity).to receive(:licensed_feature_available?)
            .with(:external_audit_events).and_return(false)
        else
          stub_licensed_features(external_audit_events: false)
        end
      end

      it { is_expected.to be_falsey }
    end

    context 'when audit events licensed feature is true' do
      before do
        if scope == :group
          allow(audit_event.root_group_entity).to receive(:licensed_feature_available?)
            .with(:external_audit_events).and_return(true)
        else
          stub_licensed_features(external_audit_events: true)
        end
      end

      context 'when audit event type is not valid for streaming' do
        before do
          if scope == :group
            create(:audit_events_group_external_streaming_destination, :http, group: audit_event.root_group_entity)
          else
            create(:audit_events_instance_external_streaming_destination, :http)
          end
        end

        it { is_expected.to be_truthy }
      end
    end
  end

  describe '#destinations' do
    subject(:get_streamer_destinations) { streamer.destinations }

    context 'when no valid destinations exist' do
      it { is_expected.to be_empty }
    end

    context 'when valid destinations exist' do
      before do
        audit_event.root_group_entity_id = group.id if scope == :group
      end

      let!(:destination) do
        if scope == :group
          group = audit_event.root_group_entity.reload
          create(:audit_events_group_external_streaming_destination, :http, group: group)
        else
          create(:audit_events_instance_external_streaming_destination, :http)
        end
      end

      it 'returns the correct destination' do
        expect(get_streamer_destinations).to contain_exactly(destination)
      end
    end
  end
end
