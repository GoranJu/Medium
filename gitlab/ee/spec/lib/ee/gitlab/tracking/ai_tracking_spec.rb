# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::AiTracking, feature_category: :value_stream_management do
  describe '.track_event', :freeze_time, :click_house do
    subject(:track_event) { described_class.track_event(event_name, **event_context) }

    let(:current_user) { build_stubbed(:user) }

    let(:event_context) do
      {
        user: current_user,
        branch_name: 'main',
        language: 'cobol',
        suggestion_size: 10,
        unique_tracking_id: "AB1"
      }
    end

    let(:event_name) { 'some_unknown_event' }

    before do
      allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(true)
    end

    context 'for unknown event' do
      let(:event_name) { 'something_unrelated' }

      it { is_expected.to be_nil }
    end

    shared_examples 'common event tracking for' do |model_class|
      context 'when clickhouse is disabled for analytics' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'does not store new event to clickhouse' do
          expect_next_instance_of(model_class, expected_event_hash) do |instance|
            expect(instance).not_to receive(:store_to_clickhouse)
          end

          track_event
        end
      end

      it 'stores new event' do
        expect_next_instance_of(model_class, expected_event_hash) do |instance|
          expect(instance).to receive(:store_to_clickhouse).once
        end

        track_event
      end

      it 'creates an event with correct attributes' do
        expect(model_class).to receive(:new).with(expected_event_hash)

        track_event
      end

      it 'triggers last_duo_activity_on update' do
        expect(Ai::UserMetrics).to receive(:refresh_last_activity_on).with(current_user).and_call_original

        track_event
      end
    end

    context 'for code suggestion event' do
      let(:event_name) { 'code_suggestion_shown_in_ide' }
      let(:expected_event_hash) do
        {
          user: current_user,
          event: event_name,
          namespace_path: nil,
          payload: {
            branch_name: 'main',
            language: 'cobol',
            suggestion_size: 10,
            unique_tracking_id: "AB1"
          }
        }
      end

      include_examples 'common event tracking for', Ai::CodeSuggestionEvent

      context 'with clickhouse not available' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'stores event to postgres' do
          expect_next_instance_of(Ai::CodeSuggestionEvent, expected_event_hash) do |instance|
            expect(instance).to receive(:store_to_pg).once
          end

          track_event
        end
      end
    end

    context 'for chat event' do
      let(:event_name) { 'request_duo_chat_response' }
      let(:expected_event_hash) do
        {
          user: current_user,
          event: event_name,
          namespace_path: nil,
          payload: {}
        }
      end

      include_examples 'common event tracking for', Ai::DuoChatEvent

      context 'with clickhouse not available' do
        before do
          allow(Gitlab::ClickHouse).to receive(:globally_enabled_for_analytics?).and_return(false)
        end

        it 'stores event to postgres' do
          expect_next_instance_of(Ai::DuoChatEvent, expected_event_hash) do |instance|
            expect(instance).to receive(:store_to_pg).once
          end

          track_event
        end
      end
    end
  end
end
