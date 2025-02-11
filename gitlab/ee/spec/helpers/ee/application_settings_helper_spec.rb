# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::ApplicationSettingsHelper, feature_category: :shared do
  include Devise::Test::ControllerHelpers
  describe '.visible_attributes' do
    it 'contains personal access token parameters' do
      expect(visible_attributes).to include(*%i[max_personal_access_token_lifetime])
    end

    it 'contains duo_features_enabled parameters' do
      expect(visible_attributes)
        .to include(*%i[duo_features_enabled lock_duo_features_enabled duo_availability enabled_expanded_logging])
    end

    it 'contains search parameters' do
      expected_fields = %i[
        global_search_code_enabled
        global_search_commits_enabled
        global_search_wiki_enabled
        global_search_epics_enabled
        global_search_snippet_titles_enabled
        global_search_users_enabled
        global_search_issues_enabled
        global_search_merge_requests_enabled
      ]
      expect(helper.visible_attributes).to include(*expected_fields)
    end

    it 'contains zoekt parameters' do
      expected_fields = %i[
        zoekt_auto_delete_lost_nodes zoekt_auto_index_root_namespace zoekt_indexing_enabled
        zoekt_indexing_paused zoekt_search_enabled zoekt_cpu_to_tasks_ratio
      ]
      expect(visible_attributes).to include(*expected_fields)
    end

    it 'contains member_promotion_management parameters' do
      expect(visible_attributes).to include(*%i[enable_member_promotion_management])
    end

    context 'when identity verification is enabled' do
      before do
        stub_saas_features(identity_verification: true)
      end

      it 'contains identity verification related attributes' do
        expect(visible_attributes).to include(*%i[
          arkose_labs_client_secret
          arkose_labs_client_xid
          arkose_labs_enabled
          arkose_labs_data_exchange_enabled
          arkose_labs_namespace
          arkose_labs_private_api_key
          arkose_labs_public_api_key
          ci_requires_identity_verification_on_free_plan
          credit_card_verification_enabled
          phone_verification_enabled
          telesign_customer_xid
          telesign_api_key
        ])
      end
    end

    context 'when identity verification is not enabled' do
      it 'does not contain identity verification related attributes' do
        expect(visible_attributes).not_to include(*%i[
          arkose_labs_client_secret
          arkose_labs_client_xid
          arkose_labs_enabled
          arkose_labs_data_exchange_enabled
          arkose_labs_namespace
          arkose_labs_private_api_key
          arkose_labs_public_api_key
          ci_requires_identity_verification_on_free_plan
          credit_card_verification_enabled
          phone_verification_enabled
          telesign_customer_xid
          telesign_api_key
        ])
      end
    end
  end

  describe '.possible_licensed_attributes' do
    it 'contains secret_push_protection_enabled' do
      expect(described_class.possible_licensed_attributes).to include(
        :secret_push_protection_available
      )
    end
  end

  describe '.registration_features_can_be_prompted?' do
    subject { helper.registration_features_can_be_prompted? }

    context 'without a valid license' do
      before do
        allow(License).to receive(:current).and_return(nil)
      end

      context 'when service ping is enabled' do
        before do
          stub_application_setting(usage_ping_enabled: true)
        end

        it { is_expected.to be_falsey }
      end

      context 'when service ping is disabled' do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it { is_expected.to be_truthy }
      end
    end

    context 'with a license' do
      let(:license) { build(:license) }

      before do
        allow(License).to receive(:current).and_return(license)
      end

      it { is_expected.to be_falsey }

      context 'when service ping is disabled' do
        before do
          stub_application_setting(usage_ping_enabled: false)
        end

        it { is_expected.to be_falsey }
      end
    end
  end

  describe '.signup_form_data' do
    let_it_be(:application_setting) { build(:application_setting) }
    let_it_be(:current_user) { build_stubbed(:admin) }
    let(:promotion_management_available) { true }

    before do
      allow(helper).to receive(:member_promotion_management_feature_available?)
        .and_return(promotion_management_available)
      application_setting.enable_member_promotion_management = true
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.signup_form_data }

    describe 'Promotion management' do
      it 'sets promotion_management_available and enable_member_promotion_management values' do
        is_expected.to match(hash_including({
          promotion_management_available: promotion_management_available.to_s,
          enable_member_promotion_management: true.to_s,
          can_disable_member_promotion_management: true.to_s,
          role_promotion_requests_path: '/admin/role_promotion_requests'
        }))
      end

      context 'when promotion management is unavailable' do
        let(:promotion_management_available) { false }

        it 'includes promotion_management_available as false' do
          is_expected.to match(hash_including({ promotion_management_available: promotion_management_available.to_s }))
        end

        it { is_expected.to match(hash_excluding(:enable_member_promotion_management)) }
      end
    end

    describe 'Licensed user count' do
      it { is_expected.to match(hash_including({ licensed_user_count: '' })) }

      context 'with a license' do
        let(:active_user_count) { 10 }

        before do
          create_current_license(plan: License::ULTIMATE_PLAN, restrictions: { active_user_count: active_user_count })
        end

        it { is_expected.to match(hash_including({ licensed_user_count: active_user_count.to_s })) }
      end
    end
  end

  describe '.deletion_protection_data' do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.deletion_adjourned_period = 1

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.deletion_protection_data }

    it { is_expected.to eq({ deletion_adjourned_period: 1 }) }
  end

  describe '.git_abuse_rate_limit_data', feature_category: :insider_threat do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.max_number_of_repository_downloads = 1
      application_setting.max_number_of_repository_downloads_within_time_period = 2
      application_setting.git_rate_limit_users_allowlist = %w[username1 username2]
      application_setting.git_rate_limit_users_alertlist = [3, 4]
      application_setting.auto_ban_user_on_excessive_projects_download = true

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    subject { helper.git_abuse_rate_limit_data }

    it 'returns the expected data' do
      is_expected.to eq({ max_number_of_repository_downloads: 1,
                          max_number_of_repository_downloads_within_time_period: 2,
                          git_rate_limit_users_allowlist: %w[username1 username2],
                          git_rate_limit_users_alertlist: [3, 4],
                          auto_ban_user_on_excessive_projects_download: 'true' })
    end
  end

  describe '#sync_purl_types_checkboxes', feature_category: :software_composition_analysis do
    let_it_be(:application_setting) { build(:application_setting) }
    let_it_be(:enabled_purl_types) { [1, 5] }

    before do
      application_setting.package_metadata_purl_types = enabled_purl_types

      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked purl type checkboxes' do
      helper.gitlab_ui_form_for(application_setting,
        url: '/admin/application_settings/security_and_compliance') do |form|
        result = helper.sync_purl_types_checkboxes(form)

        expected = ::Enums::Sbom.purl_types.map do |name, num|
          if enabled_purl_types.include?(num)
            have_checked_field(name, with: num)
          else
            have_unchecked_field(name, with: num)
          end
        end

        expect(result).to match_array(expected)
      end
    end
  end

  describe '#global_search_settings_checkboxes', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.global_search_issues_enabled = true
      application_setting.global_search_merge_requests_enabled = false
      application_setting.global_search_snippet_titles_enabled = true
      application_setting.global_search_users_enabled = false
      application_setting.global_search_code_enabled = true
      application_setting.global_search_commits_enabled = false
      application_setting.global_search_epics_enabled = true
      application_setting.global_search_wiki_enabled = true
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked checkboxes' do
      helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
        result = helper.global_search_settings_checkboxes(form)
        expect(result[0]).to have_checked_field('Enable issues tab in global search results', with: 1)
        expect(result[1]).not_to have_checked_field('Enable merge requests tab in global search results', with: 1)
        expect(result[2]).to have_checked_field('Enable snippet tab in global search results', with: 1)
        expect(result[3]).not_to have_checked_field('Enable users tab in global search results', with: 1)
        expect(result[4]).to have_checked_field('Enable code tab in global search results', with: 1)
        expect(result[5]).not_to have_checked_field('Enable commits tab in global search results', with: 1)
        expect(result[6]).to have_checked_field('Enable epics tab in global search results', with: 1)
        expect(result[7]).to have_checked_field('Enable wiki tab in global search results', with: 1)
      end
    end
  end

  describe '#zoekt_settings_checkboxes', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.zoekt_auto_delete_lost_nodes = true
      application_setting.zoekt_auto_index_root_namespace = false
      application_setting.zoekt_indexing_enabled = true
      application_setting.zoekt_indexing_paused = false
      application_setting.zoekt_search_enabled = true
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correctly checked checkboxes' do
      helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
        result = helper.zoekt_settings_checkboxes(form)
        expect(result[0]).to have_checked_field(
          "Delete offline nodes automatically after #{::Search::Zoekt::Node::LOST_DURATION_THRESHOLD.inspect}", with: 1)
        expect(result[1]).not_to have_checked_field('Index all the namespaces', with: 1)
        expect(result[2]).to have_checked_field('Enable indexing for exact code search', with: 1)
        expect(result[3]).not_to have_checked_field('Pause indexing for exact code search', with: 1)
        expect(result[4]).to have_checked_field('Enable exact code search', with: 1)
      end
    end
  end

  describe '#zoekt_settings_inputs', feature_category: :global_search do
    let_it_be(:application_setting) { build(:application_setting) }

    before do
      application_setting.zoekt_cpu_to_tasks_ratio = 1.5
      helper.instance_variable_set(:@application_setting, application_setting)
    end

    it 'returns correct inputs' do
      helper.gitlab_ui_form_for(application_setting, url: search_admin_application_settings_path) do |form|
        result = helper.zoekt_settings_inputs(form)
        expect(result[0]).to have_selector('label', text: 'Indexing CPU to tasks multiplier')
        expect(result[1])
          .to have_selector('input[type="number"][name="application_setting[zoekt_cpu_to_tasks_ratio]"][value="1.5"]')
      end
    end
  end
end
