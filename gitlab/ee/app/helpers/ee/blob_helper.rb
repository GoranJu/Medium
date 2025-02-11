# frozen_string_literal: true

module EE
  module BlobHelper
    extend ::Gitlab::Utils::Override

    override :vue_blob_header_app_data
    def vue_blob_header_app_data(project, blob, ref)
      super.merge({
        new_workspace_path: new_remote_development_workspace_path
      })
    end

    override :vue_blob_app_data
    def vue_blob_app_data(project, blob, ref)
      super.merge({
        explain_code_available: ::Gitlab::Llm::TanukiBot.enabled_for?(user: current_user, container: project).to_s,
        new_workspace_path: new_remote_development_workspace_path
      })
    end
  end
end
