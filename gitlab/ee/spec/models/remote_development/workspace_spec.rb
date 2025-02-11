# frozen_string_literal: true

require 'spec_helper'

# rubocop:disable RSpec/ MultipleMemoizedHelpers -- this is a complex model, it requires many helpers for thorough testing
RSpec.describe RemoteDevelopment::Workspace, feature_category: :workspaces do
  let_it_be(:user) { create(:user) }
  let(:workspaces_agent_config_enabled) { true }
  let(:workspaces_per_user_quota) { 10 }
  let(:workspaces_quota) { 10 }
  let(:agent_dns_zone) { 'workspace.me' }
  let(:workspace_timestamps) { { responded_to_agent_at: nil, desired_state_updated_at: nil } }
  let(:workspaces_agent_config_version) { nil }
  let_it_be(:agent, reload: true) { create(:ee_cluster_agent) }

  let(:agent_config) do
    config = create(
      :workspaces_agent_config,
      agent: agent,
      workspaces_per_user_quota: workspaces_per_user_quota,
      workspaces_quota: workspaces_quota,
      dns_zone: agent_dns_zone,
      enabled: workspaces_agent_config_enabled
    )
    agent.reload
    config
  end

  let_it_be(:project) { create(:project, :in_group) }
  let_it_be(:personal_access_token) { create(:personal_access_token, user: user) }

  let(:desired_state) { ::RemoteDevelopment::WorkspaceOperations::States::STOPPED }
  let(:actual_state) { ::RemoteDevelopment::WorkspaceOperations::States::STOPPED }

  subject(:workspace) do
    agent_config # ensure agent_config is created and associated with agent, because it is a let and lazily initialized
    build(
      :workspace, user: user, agent: agent, project: project,
      personal_access_token: personal_access_token, desired_state: desired_state,
      responded_to_agent_at: workspace_timestamps[:responded_to_agent_at],
      desired_state_updated_at: workspace_timestamps[:desired_state_updated_at],
      actual_state: actual_state,
      workspaces_agent_config_version: agent_config.versions.size
    )
  end

  describe 'associations' do
    context "for has_many" do
      it { is_expected.to have_many(:workspace_variables) }
    end

    context "for belongs_to" do
      it { is_expected.to belong_to(:user) }
      it { is_expected.to belong_to(:personal_access_token) }

      it do
        is_expected
          .to belong_to(:agent)
                .class_name('Clusters::Agent')
                .with_foreign_key(:cluster_agent_id)
                .inverse_of(:workspaces)
      end
    end

    context "when from factory" do
      before do
        # we need to save to save to allow some associations verified below to register the new workspace
        workspace.save!
      end

      it 'has correct associations from factory' do
        expect(workspace.user).to eq(user)
        expect(workspace.project).to eq(project)
        expect(workspace.agent).to eq(agent)
        expect(workspace.personal_access_token).to eq(personal_access_token)
        expect(agent.unversioned_latest_workspaces_agent_config.workspaces.first).to eq(workspace)
        expect(workspace.url_prefix).to eq("60001-#{workspace.name}")
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(workspace.url_query_string).to eq("folder=dir%2Ffile")
      end

      it 'has correct workspaces_agent_config associations from factory' do
        expect(workspace.workspaces_agent_config_version).to eq(agent_config.versions.size)
        expect(workspace.workspaces_agent_config).to eq(agent_config)
      end
    end
  end

  describe 'default values' do
    it 'has correct default values' do
      expect(workspace.desired_config_generator_version).to eq(
        RemoteDevelopment::WorkspaceOperations::DesiredConfigGeneratorVersion::LATEST_VERSION
      )
    end
  end

  describe '#url' do
    it 'returns calculated url' do
      expect(workspace.url).to eq("https://60001-#{workspace.name}.#{agent_dns_zone}/?folder=dir%2Ffile")
    end
  end

  describe '#devfile_web_url' do
    it 'returns web url to devfile' do
      # noinspection HttpUrlsUsage - suppress RubyMine warning for insecure http link.
      expect(workspace.devfile_web_url).to eq("http://#{Gitlab.config.gitlab.host}/#{workspace.project.path_with_namespace}/-/blob/main/.devfile.yaml")
    end

    context 'when devfile_path is nil' do
      before do
        workspace.devfile_path = nil
      end

      it 'returns nil as devfile_web_url' do
        expect(workspace.devfile_web_url).to eq(nil)
      end
    end
  end

  describe '.before_save' do
    describe 'when creating new record', :freeze_time do
      # NOTE: The workspaces factory overrides the desired_state_updated_at to be earlier than
      #       the current time, so we need to use build here instead of create here to test
      #       the callback which sets the desired_state_updated_at to current time upon creation.
      #       This also allows us to test the before_save callbacks.
      subject(:workspace) do
        agent_config
        build(
          :workspace,
          user: user,
          agent: agent,
          project: project
        )
      end

      it 'sets desired_state_updated_at' do
        workspace.save!
        # noinspection RubyResolve - https://handbook.gitlab.com/handbook/tools-and-tips/editors-and-ides/jetbrains-ides/tracked-jetbrains-issues/#ruby-31542
        expect(workspace.desired_state_updated_at).to eq(Time.current)
      end
    end

    describe 'when updating desired_state' do
      it 'sets desired_state_updated_at' do
        # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
        expect { workspace.update!(desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING) }.to change {
          # rubocop:enable Layout/LineLength
          workspace.desired_state_updated_at
        }
      end
    end

    describe 'when updating a field other than desired_state' do
      it 'does not set desired_state_updated_at' do
        workspace.save!
        # rubocop:todo Layout/LineLength -- this line will not be too long once we rename RemoteDevelopment namespace to Workspaces
        expect { workspace.update!(actual_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING) }.not_to change {
          # rubocop:enable Layout/LineLength
          workspace.desired_state_updated_at
        }
      end
    end
  end

  describe 'before_validation on: :create' do
    context 'when agent_config is newly created' do
      it 'sets set_workspaces_agent_config_version with size 1' do
        workspace.valid?
        expect(workspace.workspaces_agent_config_version).to eq(1)
      end
    end

    context 'when agent_config has more than 1 version' do
      before do
        agent_config.touch
      end

      it 'sets workspaces_agent_config_version to number of versions' do
        workspace.valid?
        expect(workspace.workspaces_agent_config_version).to eq(2)
      end
    end
  end

  describe '#workspaces_agent_config' do
    context 'with new unpersisted workspace record' do
      context 'when workspaces_agent_config_version is nil' do
        it 'returns latest workspaces_agent_config' do
          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end
      end
    end

    context 'with persisted workspace record' do
      context "when workspaces_agent_config_version is 0" do
        before do
          agent_config.versions.destroy_all # rubocop:disable Cop/DestroyAll -- can't use delete_all, it causes a validation err
          workspace.save!
        end

        it 'returns actual workspaces_agent_config record' do
          # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
          expect(workspace.workspaces_agent_config_version).to eq(0)

          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end
      end

      context "when workspaces_agent_config_version is 1" do
        before do
          workspace.save!
        end

        it 'returns actual workspaces_agent_config record' do
          # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
          expect(workspace.workspaces_agent_config_version).to eq(1)

          # fixture sanity check, ensure a single 'create' event version exists
          versions = agent_config.reload.versions
          expect(versions.size).to eq(1)

          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end
      end

      context "when workspaces_agent_config_version is greater than 1" do
        before do
          agent_config.touch
          workspace.save!
        end

        it 'returns reified version of workspaces_agent_config' do
          # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
          expect(workspace.workspaces_agent_config_version).to eq(2)

          # fixture sanity check, ensure a second version ('update' event type) exists
          versions = agent_config.versions.reload
          expect(versions.size).to eq(2)

          expect(workspace.workspaces_agent_config).to eq(agent_config)
        end

        context 'when workspaces_agent_config_versions gets a new version' do
          it 'still returns same workspaces_agent_config which matches the old version' do
            # fixture sanity check, ensure workspaces_agent_config_version was set properly by before_validation
            expect(workspace.workspaces_agent_config_version).to eq(2)

            agent_config.touch

            # fixture sanity check, ensure a third version ('update' event type) exists
            versions = agent_config.versions.reload
            expect(versions.size).to eq(3)

            agent_config_on_workspace = workspace.reload.workspaces_agent_config
            expect(agent_config_on_workspace.updated_at).to eq(versions[2].reify.updated_at)
            expect(agent_config_on_workspace).to eql(versions[2].reify)

            # should also not match any of the other previous versions
            expect(agent_config_on_workspace.updated_at).not_to eq(versions[1].reify.updated_at)
            # TODO: Why don't these pass? Something seems off with equality checks...
            #       We should understand this, or else it could cause unexpected behavior or bugs.
            #       https://gitlab.com/gitlab-org/gitlab/-/issues/494671
            # expect(agent_config_on_workspace).not_to eql(versions[1].reify)
            # expect(agent_config_on_workspace).not_to eq(versions[0].reify) # versions[0].reify will be nil
          end

          it 'does not return the latest workspaces_agent_config' do
            agent_config.touch

            agent_config_on_workspace = workspace.reload.workspaces_agent_config
            expect(agent_config_on_workspace.updated_at).not_to eq(agent_config.updated_at)

            # TODO: Why don't these pass? Something seems off with equality checks...
            #       We should understand this, or else it could cause unexpected behavior or bugs.
            #       https://gitlab.com/gitlab-org/gitlab/-/issues/494671
            # expect(agent_config == agent_config_on_workspace).to eq(false)
            # expect(agent_config_on_workspace == agent_config).to eq(false)
            # expect(agent_config_on_workspace).to_not eq(agent_config)
            # expect(agent_config_on_workspace.eql?(agent_config)).to eq(false)
            # expect(agent_config_on_workspace).to_not eql(agent_config)
          end
        end
      end
    end
  end

  describe 'validations' do
    context 'on agent.unversioned_latest_workspaces_agent_config' do
      context 'when no config is present' do
        let(:agent_with_no_workspaces_config) { create(:cluster_agent) }

        subject(:invalid_workspace) do
          build(:workspace, user: user, agent: agent_with_no_workspaces_config, project: project)
        end

        it 'validates presence of agent.unversioned_latest_workspaces_agent_config' do
          # sanity check of fixture
          expect(agent_with_no_workspaces_config.unversioned_latest_workspaces_agent_config).not_to be_present

          expect(invalid_workspace).not_to be_valid
          expect(invalid_workspace.errors.full_messages).to include(
            "Agent must have an associated workspaces agent config"
          )
        end
      end

      context 'on agent_config enabled' do
        context 'when agent is enabled' do
          it 'validates presence of agent.workspaces_agent_config' do
            expect(workspace).to be_valid
          end
        end

        context 'when agent is disabled' do
          let(:workspaces_agent_config_enabled) { false }

          it 'validates agent.unversioned_latest_workspaces_agent_config is enabled' do
            expect(workspace).not_to be_valid
            expect(workspace.errors[:agent])
              .to include("must have the 'enabled' flag set to true")
          end

          it "is only validated on create" do
            workspace.workspaces_agent_config_version = 1
            workspace.save(validate: false) # rubocop:disable Rails/SaveBang -- intentional to test validation
            workspace.valid?
            expect(workspace.errors[:agent]).to be_blank
          end
        end
      end
    end

    context 'on workspaces_agent_config_version' do
      context 'when version is nil' do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = nil
        end

        it 'raises error message as expected' do
          expect do
            workspace.valid?
          end.to raise_error(RuntimeError,
            "#workspaces_agent_config cannot be called until #workspaces_agent_config_version is set. " \
              "Call set_workspaces_agent_config_version first to automatically set it.")
        end
      end

      context 'when version is greater than version range' do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = agent_config.versions.size + 1
        end

        it 'raises error message as expected' do
          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include(
            'Workspaces agent config version must be no greater than the number of agent config versions'
          )
        end
      end

      context 'when version is less than 0' do
        before do
          workspace.save!
          workspace.workspaces_agent_config_version = -1
        end

        it 'raises error message as expected' do
          expect(workspace).not_to be_valid
          expect(workspace.errors.full_messages).to include(
            'Workspaces agent config version must be greater than or equal to 0'
          )
        end
      end
    end

    context 'when desired_state is Terminated' do
      let(:desired_state) { ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

      it 'prevents changes to desired_state' do
        workspace.save!
        updated = workspace.update(desired_state: ::RemoteDevelopment::WorkspaceOperations::States::STOPPED)
        expect(updated).to eq(false)
        expect(workspace).not_to be_valid
        expect(workspace.errors[:desired_state])
          .to include("is 'Terminated', and cannot be updated. Create a new workspace instead.")
      end
    end

    describe "#workspaces_count_for_current_user_and_agent" do
      let_it_be(:user1) { create(:user) }
      let_it_be(:user2) { create(:user) }
      let_it_be(:user3) { create(:user) }
      let_it_be(:agent1, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:agent2, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:workspace1) do
        create(
          :workspace, user: user1, agent: agent1,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      let_it_be(:workspace2) do
        create(
          :workspace, user: user2, agent: agent1,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(
          :workspace, user: user1, agent: agent1,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      end

      let_it_be(:workspace4) do
        create(
          :workspace, user: user2, agent: agent2,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(
          :workspace, user: user3, agent: agent2,
          desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      it "returns the correct count for the current user and agent" do
        expect(workspace1.workspaces_count_for_current_user_and_agent).to eq(2)
        expect(workspace2.workspaces_count_for_current_user_and_agent).to eq(0)
        expect(workspace4.workspaces_count_for_current_user_and_agent).to eq(0)
        expect(workspace5.workspaces_count_for_current_user_and_agent).to eq(1)
      end
    end

    describe "#workspaces_count_for_current_agent" do
      let_it_be(:agent1, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:agent2, reload: true) { create(:ee_cluster_agent, :with_existing_workspaces_agent_config) }
      let_it_be(:workspace1) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      let_it_be(:workspace2) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace3) do
        create(:workspace, agent: agent1, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::STOPPED)
      end

      let_it_be(:workspace4) do
        create(:workspace, agent: agent2, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::TERMINATED)
      end

      let_it_be(:workspace5) do
        create(:workspace, agent: agent2, desired_state: ::RemoteDevelopment::WorkspaceOperations::States::RUNNING)
      end

      it "returns the correct count for the current agent" do
        expect(workspace1.workspaces_count_for_current_agent).to eq(2)
        expect(workspace4.workspaces_count_for_current_agent).to eq(1)
        expect(workspace5.workspaces_count_for_current_agent).to eq(1)
      end
    end

    describe "#exceeds_workspaces_per_user_quota?" do
      context "when workspaces_per_user_quota is 0" do
        let(:workspaces_per_user_quota) { 0 }

        it "returns true" do
          expect(workspace.exceeds_workspaces_per_user_quota?).to be true
        end
      end

      context "when workspaces_per_user_quota is -1" do
        let(:workspaces_per_user_quota) { -1 }

        it "returns false" do
          expect(workspace.exceeds_workspaces_per_user_quota?).to be false
        end
      end

      context "when workspaces_per_user_quota is greater than 0" do
        let(:workspaces_per_user_quota) { 2 }

        it "returns true if the workspaces count for current user and agent is greater than or equal to the quota" do
          allow(workspace).to receive(:workspaces_count_for_current_user_and_agent).and_return(3)
          expect(workspace.exceeds_workspaces_per_user_quota?).to be true
        end

        it "returns false if the workspaces count for current user and agent is less than the quota" do
          allow(workspace).to receive(:workspaces_count_for_current_user_and_agent).and_return(1)
          expect(workspace.exceeds_workspaces_per_user_quota?).to be false
        end
      end
    end

    describe "#exceeds_workspaces_quota?" do
      context "when workspaces_quota is 0" do
        let(:workspaces_quota) { 0 }

        it "returns true" do
          expect(workspace.exceeds_workspaces_quota?).to be true
        end
      end

      context "when workspaces_quota is -1" do
        let(:workspaces_quota) { -1 }

        it "returns false" do
          expect(workspace.exceeds_workspaces_quota?).to be false
        end
      end

      context "when workspaces_quota is greater than 0" do
        let(:workspaces_quota) { 2 }

        it "returns true if the workspaces count for the current agent is greater than or equal to the quota" do
          allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(3)
          expect(workspace.exceeds_workspaces_quota?).to be true
        end

        it "returns false if the workspaces count for the current agent is less than the quota" do
          allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(1)
          expect(workspace.exceeds_workspaces_quota?).to be false
        end
      end
    end

    describe '#enforce_quotas' do
      it 'does not add base errors when quotas are not exceeded' do
        workspace.validate
        expect(workspace.errors[:base]).to be_empty
      end

      context "when per user quota exceeded" do
        let(:workspaces_per_user_quota) { 5 }

        it 'adds per user quota exceeded error to base error' do
          allow(workspace).to receive(:workspaces_count_for_current_user_and_agent).and_return(6)
          workspace.validate
          message = "You cannot create a workspace because you already have \"6\" \
existing workspaces for the given agent with a per user quota of \"5\" workspaces"
          expect(workspace.errors[:base]).to include(message)
        end
      end

      context "when workspace quota exceeded" do
        let(:workspaces_quota) { 3 }
        let(:valid_workspaces_per_user_quota) { workspaces_per_user_quota - 1 }

        it 'adds workspace quota error to base error' do
          allow(workspace).to receive(:workspaces_count_for_current_user_and_agent)
                                .and_return(valid_workspaces_per_user_quota)
          allow(workspace).to receive(:workspaces_count_for_current_agent).and_return(3)
          workspace.validate
          message = "You cannot create a workspace because there are already \"3\" \
existing workspaces for the given agent with a total quota of \"3\" workspaces"
          expect(workspace.errors[:base]).to include(message)
        end
      end
    end
  end

  describe 'helper_methods' do
    describe 'scopes' do
      context 'on actual_state_not_terminated' do
        context 'when workspace actual_state is not terminated' do
          let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::STOPPED }

          it 'returns workspace' do
            workspace.save!
            expect(described_class.actual_state_not_terminated).to include(workspace)
          end
        end

        context 'when workspace actual_state is terminated' do
          let(:actual_state) { RemoteDevelopment::WorkspaceOperations::States::TERMINATED }

          it 'when workspace actual_state is terminated' do
            workspace.save!
            expect(described_class.actual_state_not_terminated).not_to include(workspace)
          end
        end
      end

      context 'on with_desired_state_updated_more_recently_than_last_response_to_agent' do
        context 'when workspace responded_to_agent_at is nil' do
          it 'returns workspace' do
            workspace.save!
            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .to include(workspace)
          end
        end

        context 'when desired_state_updated_at is greater than responded_to_agent_at' do
          let(:workspace_timestamps) do
            { desired_state_updated_at: DateTime.now.new_offset("+20"),
              responded_to_agent_at: DateTime.now.new_offset("+10") }
          end

          it 'returns workspace' do
            workspace.save!
            expect(described_class.with_desired_state_updated_more_recently_than_last_response_to_agent)
              .to include(workspace)
          end
        end
      end
    end

    context 'with desired_state_updated_more_recently_than_last_response_to_agent' do
      context 'when workspace responded_to_agent_at is nil' do
        it 'returns true' do
          expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to eq(true)
        end
      end

      context 'when desired_state_updated_at is greater than responded_to_agent_at' do
        let(:workspace_timestamps) do
          { desired_state_updated_at: DateTime.now.new_offset("+20"),
            responded_to_agent_at: DateTime.now.new_offset("+10") }
        end

        it 'returns true' do
          workspace.save!
          expect(workspace.desired_state_updated_more_recently_than_last_response_to_agent?).to eq(true)
        end
      end
    end
  end
end
# rubocop:enable RSpec/ MultipleMemoizedHelpers
