# frozen_string_literal: true

### Requires a context containing:
# - expected_message_value: message string to be updated
# - key: field name to be updated
RSpec.shared_examples 'updating chat storage message extras' do
  let(:chat_storage) { instance_double(Gitlab::Llm::ChatStorage) }
  let(:ai_request) { double }

  before do
    allow(Gitlab::Llm::ChatStorage).to receive(:new).and_return(chat_storage)
    allow(ai_request).to receive(:request).and_return(ai_response)
    allow(context).to receive(:ai_request).and_return(ai_request)
    allow(chat_storage).to receive(:update_message_extras)
  end

  it 'updates chat storage message extras' do
    tool.execute

    expect(chat_storage).to have_received(:update_message_extras).with(
      context.request_id, key, a_string_including(expected_message_value)
    )
  end
end
