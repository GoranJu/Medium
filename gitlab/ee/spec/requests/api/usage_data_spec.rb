# frozen_string_literal: true

require 'spec_helper'

RSpec.describe API::UsageData, feature_category: :service_ping do
  let_it_be(:user) { create(:user) }

  describe 'POST /usage_data/track_event' do
    let(:endpoint) { '/usage_data/track_event' }

    before do
      stub_application_setting(usage_ping_enabled: true, use_clickhouse_for_analytics: true)
    end

    context 'with AI related metric' do
      let_it_be(:additional_properties) do
        {
          language: 'ruby',
          timestamp: '2024-01-01',
          unrelated_info: 'bar',
          branch_name: 'foo'
        }
      end

      let_it_be(:allowed_fields_for_internal_event) do
        # Does not persist branch name on internal telemetry
        additional_properties.except(:branch_name).symbolize_keys
      end

      let(:event_name) { 'code_suggestion_shown_in_ide' }

      it 'triggers AI tracking' do
        expect(Gitlab::InternalEvents).to receive(:track_event)
                                            .with(
                                              event_name,
                                              additional_properties: allowed_fields_for_internal_event,
                                              project: nil,
                                              namespace: nil,
                                              send_snowplow_event: false,
                                              user: user
                                            )

        expect(Gitlab::Tracking::AiTracking).to receive(:track_event)
                                                  .with(
                                                    event_name,
                                                    additional_properties.merge(user: user)
                                                  ).and_call_original

        post api(endpoint, user), params: {
          event: event_name,
          additional_properties: additional_properties
        }

        expect(response).to have_gitlab_http_status(:ok)
      end
    end
  end
end
