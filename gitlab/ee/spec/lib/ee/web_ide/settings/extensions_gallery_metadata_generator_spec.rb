# frozen_string_literal: true

require "fast_spec_helper"

RSpec.describe WebIde::Settings::ExtensionsGalleryMetadataGenerator, feature_category: :web_ide do
  using RSpec::Parameterized::TableSyntax

  let(:user_class) { stub_const('User', Class.new) }
  let(:group_class) { stub_const('Namespace', Class.new) }
  let(:user) { user_class.new }
  let(:group) { group_class.new }
  let(:input_context) do
    {
      requested_setting_names: [:vscode_extensions_gallery_metadata],
      options: {
        user: user,
        vscode_extensions_marketplace_feature_flag_enabled: true
      },
      settings: {}
    }
  end

  subject(:actual_settings) do
    described_class.generate(input_context).dig(:settings, :vscode_extensions_gallery_metadata)
  end

  where(
    :enterprise_group,
    :enterprise_group_enabled,
    :expectation
  ) do
    nil | false | { enabled: false, disabled_reason: :opt_in_unset }
    ref(:group) | false | { enabled: false, disabled_reason: :enterprise_group_disabled }
    ref(:group) | true  | { enabled: false, disabled_reason: :opt_in_unset }
  end

  with_them do
    before do
      allow(user).to receive(:enterprise_user?).and_return(!!enterprise_group)
      allow(user).to receive(:enterprise_group).and_return(enterprise_group)
      # note: Leaving user's opt_in unset so we can test that the CE checks are still running
      allow(user).to receive(:extensions_marketplace_opt_in_status).and_return(:unset)
      allow(group).to receive(:enterprise_users_extensions_marketplace_enabled?).and_return(enterprise_group_enabled)
    end

    it "adds settings with disabled reason based on enterprise_group presence and setting" do
      expect(actual_settings).to eq(expectation)
    end
  end
end
