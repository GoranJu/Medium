# frozen_string_literal: true

require 'spec_helper'

RSpec.describe 'Project settings > CI / CD > Secrets', :js, feature_category: :secrets_management do
  using RSpec::Parameterized::TableSyntax

  let_it_be(:project) { create(:project, :public) }
  let_it_be(:maintainer) { create(:user, maintainer_of: project) }
  let_it_be(:reporter) { create(:user, reporter_of: project) }

  describe 'secrets settings section' do
    where(:user, :feature_flag_value, :should_render) do
      ref(:maintainer) | true  | true
      ref(:maintainer) | false | false
      ref(:reporter)   | true  | false
      ref(:reporter)   | false | false
    end

    with_them do
      before do
        sign_in(user)
        stub_feature_flags(ci_tanukey_ui: feature_flag_value)
        visit project_settings_ci_cd_path(project)
      end

      subject { page.has_selector?('#js-secrets-settings') }

      it { is_expected.to eq(should_render) }
    end
  end
end
