# frozen_string_literal: true

require 'spec_helper'

RSpec.describe ::WebIde::Settings, feature_category: :web_ide do # rubocop:disable RSpec/SpecFilePathFormat -- This cop fails because the spec is named 'settings_integration_spec.rb' but describes ::WebIde::Settings class. But we want it that way, because it's an integration spec, not a unit spec, but we still want to be able to use `described_class`
  let_it_be_with_reload(:group) { create(:group, :private) }
  let_it_be_with_reload(:user) { create(:enterprise_user, enterprise_group: group) }
  let_it_be(:options) do
    {
      user: user,
      vscode_extensions_marketplace_feature_flag_enabled: true
    }
  end

  subject(:settings) { described_class.get([:vscode_extensions_gallery_metadata], options) }

  before do
    stub_feature_flags(vscode_web_ide: true, web_ide_extensions_marketplace: true)
    stub_licensed_features(disable_extensions_marketplace_for_enterprise_users: true)
    user.update!(extensions_marketplace_enabled: true)
  end

  describe "default - enterprise group has extensions marketplace disabled" do
    it do
      is_expected.to include(vscode_extensions_gallery_metadata: {
        disabled_reason: :enterprise_group_disabled,
        enabled: false
      })
    end
  end

  describe "enterprise group has extensions marketplace enabled" do
    before do
      group.update!(enterprise_users_extensions_marketplace_enabled: true)
    end

    it do
      is_expected.to include(vscode_extensions_gallery_metadata: {
        enabled: true
      })
    end
  end
end
