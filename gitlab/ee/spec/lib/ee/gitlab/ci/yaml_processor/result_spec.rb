# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Ci::YamlProcessor::Result, feature_category: :pipeline_composition do
  include StubRequests

  let_it_be(:user) { create(:user) }

  let(:ci_config) { Gitlab::Ci::Config.new(config_content, user: user) }
  let(:result) { described_class.new(ci_config: ci_config, warnings: ci_config&.warnings) }

  subject(:build) { result.builds.first }

  describe '#builds' do
    context 'when a job has identity', feature_category: :secrets_management do
      let(:config_content) do
        YAML.dump(
          test: { stage: 'test', script: 'echo', identity: 'google_cloud' }
        )
      end

      before do
        stub_saas_features(google_cloud_support: true)
      end

      it 'includes :identity in :options' do
        expect(build.dig(:options, :identity)).to eq('google_cloud')
      end
    end

    describe 'execution_policy_job' do
      include_context 'with pipeline policy context'

      let(:creating_policy_pipeline) { true }
      let(:ci_config) do
        Gitlab::Ci::Config.new(config_content, user: user, pipeline_policy_context: pipeline_policy_context)
      end

      let(:config_content) do
        YAML.dump(
          test: { stage: 'test', script: 'echo' }
        )
      end

      it 'marks the build as `execution_policy_job` in :options' do
        expect(build.dig(:options, :execution_policy_job)).to eq true
      end

      context 'when creating_policy_pipeline? is false' do
        let(:creating_policy_pipeline) { false }

        it 'does not mark the build as `execution_policy_job` via :options' do
          expect(build.dig(:options, :execution_policy_job)).to be_nil
        end
      end
    end
  end
end
