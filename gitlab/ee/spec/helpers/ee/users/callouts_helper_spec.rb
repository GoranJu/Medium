# frozen_string_literal: true

require "spec_helper"

RSpec.describe EE::Users::CalloutsHelper do
  include Devise::Test::ControllerHelpers
  using RSpec::Parameterized::TableSyntax

  describe '#render_dashboard_ultimate_trial', :saas do
    let_it_be(:namespace) { build_stubbed(:namespace) }
    let_it_be(:user) { namespace.owner }

    let(:show_ultimate_trial?) { true }
    let(:user_default_dashboard?) { true }
    let(:owns_paid_namespace?) { false }
    let(:owns_group_without_trial?) { true }

    let(:render) { helper.render_dashboard_ultimate_trial(user) }

    before do
      allow(helper).to receive(:show_ultimate_trial?).with(user, described_class::ULTIMATE_TRIAL).and_return(show_ultimate_trial?)
      allow(helper).to receive(:user_default_dashboard?).with(user).and_return(user_default_dashboard?)
      allow(user).to receive(:owns_paid_namespace?).and_return(owns_paid_namespace?)
      allow(user).to receive(:owns_group_without_trial?).and_return(owns_group_without_trial?)
    end

    context 'when all conditions are met' do
      it 'renders the ultimate_with_enterprise_trial_callout_content' do
        expect(helper).to receive(:render).with('shared/ultimate_with_enterprise_trial_callout_content')
        render
      end
    end

    context 'when show_ultimate_trial? is false' do
      let(:show_ultimate_trial?) { false }

      it 'does not render any content' do
        expect(helper).not_to receive(:render)
        render
      end
    end

    context 'when user_default_dashboard? is false' do
      let(:user_default_dashboard?) { false }

      it 'does not render any content' do
        expect(helper).not_to receive(:render)
        render
      end
    end

    context 'when user owns a paid namespace' do
      let(:owns_paid_namespace?) { true }

      it 'does not render any content' do
        expect(helper).not_to receive(:render)
        render
      end
    end

    context 'when user does not own a group without trial' do
      let(:owns_group_without_trial?) { false }

      it 'does not render any content' do
        expect(helper).not_to receive(:render)
        render
      end
    end
  end

  describe '#render_two_factor_auth_recovery_settings_check' do
    let(:user_two_factor_disabled) { create(:user) }
    let(:user_two_factor_enabled) { create(:user, :two_factor) }
    let(:anonymous) { nil }

    where(:kind_of_user, :is_gitlab_com?, :dismissed_callout?, :should_render?) do
      :anonymous                | false | false | false
      :anonymous                | true  | false | false
      :user_two_factor_disabled | false | false | false
      :user_two_factor_disabled | true  | false | false
      :user_two_factor_disabled | true  | true  | false
      :user_two_factor_enabled  | false | false | false
      :user_two_factor_enabled  | true  | false | true
      :user_two_factor_enabled  | true  | true  | false
    end

    with_them do
      before do
        user = send(kind_of_user)
        allow(helper).to receive(:current_user).and_return(user)
        allow(Gitlab).to receive(:com?).and_return(is_gitlab_com?)
        allow(user).to receive(:dismissed_callout?).and_return(dismissed_callout?) if user
      end

      it do
        if should_render?
          expect(helper).to receive(:render).with('shared/two_factor_auth_recovery_settings_check')
        else
          expect(helper).not_to receive(:render)
        end

        helper.render_two_factor_auth_recovery_settings_check
      end
    end
  end

  describe '.show_new_user_signups_cap_reached?' do
    subject { helper.show_new_user_signups_cap_reached? }

    let(:user) { create(:user) }
    let(:admin) { create(:user, admin: true) }

    context 'when user is anonymous' do
      before do
        allow(helper).to receive(:current_user).and_return(nil)
      end

      it { is_expected.to eq(false) }
    end

    context 'when user is not an admin' do
      before do
        allow(helper).to receive(:current_user).and_return(user)
      end

      it { is_expected.to eq(false) }
    end

    context 'when feature flag is enabled', :do_not_mock_admin_mode_setting do
      where(:seat_control_user_cap, :new_user_signups_cap, :active_user_count, :result) do
        false | nil | 10 | false
        true  | 10  | 9  | false
        true  | 1   | 10 | true
        true  | 1   | 1  | true
      end

      with_them do
        before do
          allow(helper).to receive(:current_user).and_return(admin)
          allow(User.billable).to receive(:count).and_return(active_user_count)
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:new_user_signups_cap).and_return(new_user_signups_cap)
          allow(Gitlab::CurrentSettings.current_application_settings)
            .to receive(:seat_control_user_cap?).and_return(seat_control_user_cap)
        end

        it { is_expected.to eq(result) }
      end
    end
  end

  describe '#show_pipl_compliance_alert?' do
    let_it_be(:pipl_user) { create(:pipl_user, :notified) }
    let_it_be(:user) { pipl_user.user }

    subject(:show_pipl_compliance_alert?) { helper.show_pipl_compliance_alert? }

    before do
      allow(helper).to receive(:current_user).and_return(user)
      allow(ComplianceManagement::Pipl).to receive(:user_subject_to_pipl?).and_return(true)
    end

    it 'does not allow the alert to be displayed' do
      expect(show_pipl_compliance_alert?).to be(false)
    end

    context 'when on saas feature is available' do
      before do
        stub_saas_features(pipl_compliance: true)
      end

      it 'allows the alert to be displayed' do
        expect(show_pipl_compliance_alert?).to be(true)
      end

      context 'when the callout is dismissed' do
        before do
          allow(helper).to receive(:user_dismissed?).and_return(true)
        end

        it 'does not show the alert' do
          expect(show_pipl_compliance_alert?).to be(false)
        end
      end

      context 'when enforce_pipl_compliance is disabled' do
        before do
          stub_feature_flags(enforce_pipl_compliance: false)
        end

        it 'does not show the alert' do
          expect(show_pipl_compliance_alert?).to be(false)
        end
      end

      context 'when the user is not subject to pipl' do
        before do
          allow(ComplianceManagement::Pipl).to receive(:user_subject_to_pipl?).and_return(false)
        end

        it 'does not show the alert' do
          expect(show_pipl_compliance_alert?).to be(false)
        end
      end

      context 'when the email has not been sent yet' do
        before do
          pipl_user.reset_notification!
        end

        it 'does not show the alert' do
          expect(show_pipl_compliance_alert?).to be(false)
        end
      end
    end
  end

  describe '#dismiss_two_factor_auth_recovery_settings_check' do
    let_it_be(:user) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    it 'dismisses `TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK` callout' do
      expect(::Users::DismissCalloutService)
        .to receive(:new)
        .with(
          container: nil,
          current_user: user,
          params: { feature_name: described_class::TWO_FACTOR_AUTH_RECOVERY_SETTINGS_CHECK }
        )
        .and_call_original

      helper.dismiss_two_factor_auth_recovery_settings_check
    end
  end

  describe '#web_hook_disabled_dismissed?', feature_category: :webhooks do
    let_it_be(:user, refind: true) { create(:user) }

    before do
      allow(helper).to receive(:current_user).and_return(user)
    end

    context 'with a group' do
      let_it_be(:group) { create(:group) }
      let(:factory) { :group_callout }
      let(:container_key) { :group }
      let(:container) { group }
      let(:key) { "web_hooks:last_failure:group-#{group.id}" }

      include_examples 'CalloutsHelper#web_hook_disabled_dismissed shared examples'
    end
  end

  # This test fails with Rails 7.0.8 + rails-dom-testing 2.2.0
  # However it passes with:
  #  - Rails 7.0.8 + rails-dom-testing 2.0.3
  #  - Rails 7.1.3 + rails-dom-testing 2.2.0
  #
  #  TODO: Either investigate it on rails-dom-testing gem upgrade or remove this comment after 7.1.3 upgrade
  #
  #  Related to Gitlab.next_rails?
  describe '.show_joining_a_project_alert?', feature_category: :onboarding do
    where(:cookie_present?, :onboarding?, :user_dismissed_callout?, :expected_result) do
      true | true | true | false
      false | true | true | false
      true | false | true | false
      true | true | false | true
    end

    with_them do
      before do
        cookies[:signup_with_joining_a_project] = cookie_present?
        allow(::Gitlab::Saas).to receive(:feature_available?).with(:onboarding).and_return(onboarding?)
        allow(helper).to receive(:user_dismissed?).and_return(user_dismissed_callout?)
      end

      subject { helper.show_joining_a_project_alert? }

      it { is_expected.to eq(expected_result) }
    end
  end

  describe '.show_transition_to_jihu_callout?', :do_not_mock_admin_mode_setting do
    let_it_be(:admin) { create(:user, :admin) }
    let_it_be(:user) { create(:user) }

    subject { helper.show_transition_to_jihu_callout? }

    using RSpec::Parameterized::TableSyntax

    where(:gitlab_com_subscriptions_enabled, :gitlab_jh, :has_active_license, :current_user, :timezone, :user_dismissed, :expected_result) do
      false | false | false | ref(:admin) | 'Asia/Hong_Kong'      | false | true
      false | false | false | ref(:admin) | 'Asia/Shanghai'       | false | true
      false | false | false | ref(:admin) | 'Asia/Macau'          | false | true
      false | false | false | ref(:admin) | 'Asia/Chongqing'      | false | true

      true  | false | false | ref(:admin) | 'Asia/Shanghai'       | false | false
      false | true  | false | ref(:admin) | 'Asia/Shanghai'       | false | false
      false | false | true  | ref(:admin) | 'Asia/Shanghai'       | false | false
      false | false | false | ref(:user)  | 'Asia/Shanghai'       | false | false
      false | false | false | ref(:admin) | 'America/Los_Angeles' | false | false
      false | false | false | ref(:admin) | 'Asia/Shanghai'       | true  | false
    end

    with_them do
      before do
        stub_saas_features(gitlab_com_subscriptions: gitlab_com_subscriptions_enabled)
        allow(::Gitlab).to receive(:jh?).and_return(gitlab_jh)
        allow(helper).to receive(:has_active_license?).and_return(has_active_license)
        allow(helper).to receive(:current_user).and_return(current_user)
        allow(helper).to receive(:user_dismissed?).with(::Users::CalloutsHelper::TRANSITION_TO_JIHU_CALLOUT) { user_dismissed }
        allow(current_user).to receive(:timezone).and_return(timezone)
      end

      it { is_expected.to be expected_result }
    end
  end
end
