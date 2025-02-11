# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Duo::Developments::Setup, :gitlab_duo, :silence_stdout, feature_category: :duo_chat do
  include RakeHelpers

  let_it_be(:group) { create(:group, :with_organization, path: 'test-group') }
  let_it_be(:project) { create(:project, group: group) }
  let_it_be(:user) { create(:user, maintainer_of: project, username: 'root') }

  let(:task) { described_class.new(args) }
  let(:rake_task) { instance_double(Rake::Task, invoke: true) }

  let(:feature_flags) do
    [
      :summarize_my_code_review,
      :enable_hamilton_in_user_preferences,
      :allow_organization_creation
    ]
  end

  subject(:setup) { task.execute }

  before do
    allow(Rake::Task).to receive(:[]).with(any_args).and_return(rake_task)
    feature_flags.each { |flag| ::Feature.disable(flag) }
    create_current_license_without_expiration(plan: License::ULTIMATE_PLAN)
  end

  shared_examples 'checks for dev or test env' do
    context 'with production environment' do
      before do
        allow(::Gitlab).to receive(:dev_or_test_env?).and_return(false)
      end

      it 'raises an error' do
        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'errors when GITLAB_SIMULATE_SAAS has unexpected value' do |expected_gitlab_simulate_saas_env|
    context 'when GITLAB_SIMULATE_SAAS has unexpected value' do
      before do
        stub_const('ENV', { 'GITLAB_SIMULATE_SAAS' => !expected_gitlab_simulate_saas_env })
      end

      it 'raises an error' do
        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'enables all necessary feature flags' do
    it 'enables all necessary feature flags', :aggregate_failures do
      setup

      feature_flags.each do |flag|
        expect(::Feature.enabled?(flag)).to be_truthy # rubocop:disable Gitlab/FeatureFlagWithoutActor -- For dev
      end
    end
  end

  shared_examples 'errors when there is no license' do
    context 'when there is no license' do
      it 'raises an error' do
        License.delete_all

        expect { setup }.to raise_error(RuntimeError)
      end
    end
  end

  shared_examples 'creates add-on purchases' do
    it 'creates enterprise add-on purchases', :aggregate_failures do
      setup

      expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(0)
      expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(1)
    end
  end

  context 'when simulating GitLabCom: passing target group as an argument', :saas do
    let(:args) { { root_group_path: group.path } }

    before do
      stub_env('GITLAB_SIMULATE_SAAS', '1')
    end

    context 'when group does not exist' do
      let(:args) { { root_group_path: 'new-path' } }

      it 'creates a new group' do
        expect { setup }.to change { ::Group.count }.by(1)
      end

      it 'adds user to group' do
        setup

        expect(Group.find_by_path('new-path').reload.users).to include(user)
      end

      context 'when failed to create a group' do
        let(:args) { { root_group_path: '!!!!!' } }

        it 'raises an error' do
          expect { setup }.to raise_error(RuntimeError)
        end
      end
    end

    context 'when group already exists' do
      it 'does not create a new group' do
        expect { setup }.not_to change { ::Group.count }
      end

      it 'adds user to group' do
        setup

        expect(group.reload.users).to include(user)
      end
    end

    context 'when creating duo pro add on' do
      let(:args) { { root_group_path: 'test', add_on: 'duo_pro' } }

      it 'creates duo pro add-on only' do
        setup

        expect(::GitlabSubscriptions::AddOnPurchase.for_gitlab_duo_pro.count).to eq(1)
        expect(::GitlabSubscriptions::AddOnPurchase.for_duo_enterprise.count).to eq(0)
      end
    end

    it_behaves_like 'checks for dev or test env'
    it_behaves_like 'errors when GITLAB_SIMULATE_SAAS has unexpected value', true
    it_behaves_like 'enables all necessary feature flags'
    it_behaves_like 'errors when there is no license'
    it_behaves_like 'creates add-on purchases'

    context 'when updating application setting' do
      it 'changes application settings' do
        expect { setup }.to change {
                              Gitlab::CurrentSettings.current_application_settings.check_namespace_plan
                            }.to(true)
         .and change {
                Gitlab::CurrentSettings.current_application_settings
                                              .allow_local_requests_from_web_hooks_and_services
              }.to(true)
      end
    end
  end

  context 'when simulating SelfManaged: applying for entire instance, no group argument expected' do
    before do
      stub_env('GITLAB_SIMULATE_SAAS', '0')
    end

    let(:args) { {} }

    context 'when License does not exist' do
      it 'raises an error' do
        License.delete_all

        expect { setup }.to raise_error(RuntimeError)
      end
    end

    it_behaves_like 'errors when GITLAB_SIMULATE_SAAS has unexpected value', false
    it_behaves_like 'checks for dev or test env'
    it_behaves_like 'enables all necessary feature flags'
    it_behaves_like 'errors when there is no license'
    it_behaves_like 'creates add-on purchases'
  end
end
