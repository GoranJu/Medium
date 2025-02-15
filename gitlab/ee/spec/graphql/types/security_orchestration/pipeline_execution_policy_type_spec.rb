# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['PipelineExecutionPolicy'], feature_category: :security_policy_management do
  let(:fields) do
    %i[description edit_path enabled name updated_at yaml policy_scope source policy_blob_file_path warnings]
  end

  it { expect(described_class).to have_graphql_fields(fields) }
end
