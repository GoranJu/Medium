# frozen_string_literal: true

namespace :gitlab do
  namespace :duo do
    desc 'GitLab | Duo | Enable GitLab Duo features on the specified group'
    task :setup, [:root_group_path, :add_on] => :environment do |_, args|
      Gitlab::Duo::Developments::Setup.new(args).execute
    end

    desc 'GitLab | Duo | Enable GitLab Duo features for the instance'
    task :setup_instance, [:add_on] => :environment do |_, args|
      Gitlab::Duo::Developments::Setup.new(args).execute
    end

    desc 'GitLab | Duo | Enable GitLab Duo feature flags'
    task enable_feature_flags: :gitlab_environment do
      Gitlab::Duo::Developments::FeatureFlagEnabler.execute
    end

    desc 'GitLab | Duo | Create evaluation-ready group'
    task :setup_evaluation, [:root_group_path] => :environment do |_, args|
      group = Gitlab::Duo::Developments::Setup.new(args).execute
      Gitlab::Duo::Developments::SetupGroupsForModelEvaluation.new(group).execute
    end

    desc 'GitLab | Duo | Verify self-hosted Duo setup'
    task :verify_self_hosted_setup, [:username] => :gitlab_environment do |_, args|
      Gitlab::Duo::Administration::VerifySelfHostedSetup.new(args[:username]).execute
    end
  end
end
