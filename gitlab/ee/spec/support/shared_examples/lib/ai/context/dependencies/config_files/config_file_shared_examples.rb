# frozen_string_literal: true

# These examples are intended to test Ai::Context::Dependencies::ConfigFiles::Base child classes.

### Requires a context containing:
#  - config_file_content: Formatted string content of a valid dependency config file
#  - expected_formatted_lib_names: Array of library names (and their version in brackets if applicable)
#
### Optionally, the context can contain:
#  - config_file_class: The config file class to use instead of `described_class`
#
RSpec.shared_examples 'parsing a valid dependency config file' do
  let(:blob) { double(path: 'path/to/file', data: config_file_content, project: instance_double('Project', id: 123)) } # rubocop: disable RSpec/VerifiedDoubles -- Inherits from both Gitlab::Git::Blob and Blob
  let(:config_file) { (try(:config_file_class) || described_class).new(blob) }

  it 'returns the expected payload' do
    config_file.parse!

    expect(config_file).to be_valid
    expect(config_file.payload).to match({
      libs: match_array(expected_formatted_lib_names.map { |lib_name| { name: lib_name } }),
      file_path: blob.path
    })
  end
end

### Optionally, the context can contain:
#  - invalid_config_file_content: Content of an invalid dependency config file
#  - config_file_class: The config file class to use instead of `described_class`
#  - expected_error_message: Message when an error occurs
#
RSpec.shared_examples 'parsing an invalid dependency config file' do
  let(:config_file_content) { try(:invalid_config_file_content) || 'invalid' }
  let(:blob) { double(path: 'path/to/file', data: config_file_content, project: instance_double('Project', id: 123)) } # rubocop: disable RSpec/VerifiedDoubles -- Inherits from both Gitlab::Git::Blob and Blob
  let(:config_file) { (try(:config_file_class) || described_class).new(blob) }
  let(:default_error_message) { 'unexpected format or dependencies not present' }

  it 'returns an error message' do
    config_file.parse!

    expect(config_file).not_to be_valid
    expect(config_file.error_message).to eq(
      "Error(s) while parsing file `#{blob.path}`: #{try(:expected_error_message) || default_error_message}")
    expect(config_file.payload).to be_nil
  end
end
