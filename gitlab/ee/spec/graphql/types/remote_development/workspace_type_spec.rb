# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSchema.types['Workspace'], feature_category: :workspaces do
  let(:fields) do
    %i[
      id cluster_agent project_id user name namespace max_hours_before_termination
      desired_state desired_state_updated_at actual_state responded_to_agent_at
      url editor devfile_ref devfile_path devfile_web_url devfile processed_devfile
      project_ref deployment_resource_version desired_config_generator_version
      workspaces_agent_config_version force_include_all_resources created_at updated_at
      workspace_variables
    ]
  end

  specify { expect(described_class.graphql_name).to eq('Workspace') }

  specify { expect(described_class).to have_graphql_fields(fields) }

  specify { expect(described_class).to require_graphql_authorizations(:read_workspace) }
end
