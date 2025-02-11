# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe ::RemoteDevelopment::WorkspaceOperations::Create::PreFlattenDevfileValidator, feature_category: :workspaces do
  include ResultMatchers

  include_context 'with remote development shared fixtures'

  let(:devfile_name) { "example.devfile.yaml" }
  let(:devfile) { yaml_safe_load_symbolized(read_devfile_yaml(devfile_name)) }
  let(:context) { { devfile: devfile } }

  subject(:result) do
    described_class.validate(context)
  end

  context 'for devfiles containing no violations' do
    it 'returns an ok Result containing the original context' do
      expect(result).to eq(
        Gitlab::Fp::Result.ok({
          devfile: devfile
        })
      )
    end
  end

  context 'for devfiles containing pre flatten violations' do
    using RSpec::Parameterized::TableSyntax

    # rubocop:disable Layout/LineLength -- We don't want to wrap RSpec::Parameterized::TableSyntax, it hurts readability
    where(:devfile_name, :error_str) do
      "example.invalid-unsupported-parent-inheritance-devfile.yaml" | "Inheriting from 'parent' is not yet supported"
      "example.invalid-unsupported-schema-version-devfile.yaml" | "'schemaVersion' '2.0.0' is not supported, it must be '2.2.0'"
      "example.invalid-invalid-schema-version-devfile.yaml" | "Invalid 'schemaVersion' 'example'"
    end
    # rubocop:enable Layout/LineLength

    with_them do
      it 'returns an err Result containing error details' do
        expect(result).to be_err_result do |message|
          expect(message).to be_a(RemoteDevelopment::Messages::WorkspaceCreatePreFlattenDevfileValidationFailed)
          message.content => { details: String => error_details }
          expect(error_details).to eq(error_str)
        end
      end
    end
  end
end
