# frozen_string_literal: true

RSpec.shared_examples_for 'policy metrics with logging' do |histogram_name|
  let(:expected_logged_data) { { 'duration' => kind_of(Float) } }
  let(:histogram) do
    Security::SecurityOrchestrationPolicies::ObserveHistogramsService.histogram(histogram_name)
  end

  it 'tracks metrics' do
    expect(histogram).to receive(:observe).with({}, kind_of(Float)).and_call_original

    subject
  end

  it 'logs duration' do
    expect(Gitlab::AppJsonLogger).to receive(:debug).with(hash_including(expected_logged_data)).and_call_original

    subject
  end
end
