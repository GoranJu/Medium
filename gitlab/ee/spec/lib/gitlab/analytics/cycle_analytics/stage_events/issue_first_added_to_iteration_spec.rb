# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Analytics::CycleAnalytics::StageEvents::IssueFirstAddedToIteration, feature_category: :value_stream_management do
  let_it_be(:event_factory) { :resource_iteration_event }
  let_it_be(:model_factory) { :issue }

  it_behaves_like 'value stream analytics event'

  it_behaves_like 'LEFT JOIN-able value stream analytics event' do
    let_it_be(:record_with_data) { create(:issue).tap { |i| create(:resource_iteration_event, issue: i) } }
    let_it_be(:record_without_data) { create(:issue) }
  end

  it_behaves_like 'value stream analytics first assignment event methods'
end
