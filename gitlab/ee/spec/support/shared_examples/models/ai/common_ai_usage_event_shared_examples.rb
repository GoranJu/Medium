# frozen_string_literal: true

RSpec.shared_examples 'common ai_usage_event' do
  describe '#to_clickhouse_csv_row', :freeze_time do
    let(:event) { described_class.new(attributes.with_indifferent_access) }
    let(:attributes) do
      { user: user, timestamp: '2021-01-01'.to_datetime, event: described_class.events.each_key.first }
    end

    let(:user) { build_stubbed(:user) }

    it 'returns 3 required fields' do
      expect(event.to_clickhouse_csv_row).to include(
        user_id: user.id,
        timestamp: '2021-01-01'.to_datetime.to_i,
        event: described_class.events.each_value.first
      )
    end
  end

  describe '.related_event?' do
    it 'is true for events from events enum' do
      expect(described_class.related_event?(described_class.events.each_key.first)).to be_truthy
      expect(described_class.related_event?('unrelated_event')).to be_falsey
    end
  end
end
