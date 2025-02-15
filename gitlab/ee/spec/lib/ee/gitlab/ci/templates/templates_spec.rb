# frozen_string_literal: true

require 'spec_helper'

RSpec.describe "CI YML Templates", feature_category: :pipeline_composition do
  using RSpec::Parameterized::TableSyntax
  subject { Gitlab::Ci::YamlProcessor.new(content).execute }

  let(:all_templates) { Gitlab::Template::GitlabCiYmlTemplate.all.map(&:full_name) }

  shared_examples 'require default stages to be included' do
    it 'require default stages to be included' do
      expect(subject.stages).to include(*Gitlab::Ci::Config::Entry::Stages.default)
    end
  end

  context 'that support autodevops' do
    exceptions = [
      'Diffblue-Cover.gitlab-ci.yml',        # no auto-devops
      'Security/DAST.gitlab-ci.yml',         # DAST stage is defined inside AutoDevops yml
      'Security/DAST-API.gitlab-ci.yml',     # no auto-devops
      'Security/API-Fuzzing.gitlab-ci.yml',  # no auto-devops
      'Security/API-Security.gitlab-ci.yml', # no auto-devops
      'ThemeKit.gitlab-ci.yml'               # No AutoDevops support
    ]

    where(:template_name) do
      all_templates - exceptions
    end

    with_them do
      let(:content) do
        <<~EOS
          include:
            - template: #{template_name}

          concrete_build_implemented_by_a_user:
            stage: test
            script: do something
        EOS
      end

      it 'are valid with default stages', quarantine: 'https://gitlab.com/gitlab-org/gitlab/-/issues/433350' do
        expect(subject).to be_valid
      end

      include_examples 'require default stages to be included'
    end
  end

  context 'that do not support autodevops' do
    context 'when DAST API template' do
      # The DAST API template purposly excludes a stages
      # definition.

      let(:template_name) { 'Security/DAST-API.gitlab-ci.yml' }

      context 'with default stages' do
        let(:content) do
          <<~EOS
            include:
              - template: #{template_name}

            concrete_build_implemented_by_a_user:
              stage: test
              script: do something
          EOS
        end

        it { is_expected.not_to be_valid }
      end

      context 'with defined stages' do
        let(:content) do
          <<~EOS
            include:
              - template: #{template_name}

            stages:
              - build
              - test
              - deploy
              - dast

            concrete_build_implemented_by_a_user:
              stage: test
              script: do something
          EOS
        end

        it { is_expected.to be_valid }

        include_examples 'require default stages to be included'
      end
    end

    context 'when API Fuzzing template' do
      # The API Fuzzing template purposly excludes a stages
      # definition.

      let(:template_name) { 'Security/API-Fuzzing.gitlab-ci.yml' }

      context 'with default stages' do
        let(:content) do
          <<~EOS
            include:
              - template: #{template_name}

            concrete_build_implemented_by_a_user:
              stage: test
              script: do something
          EOS
        end

        it { is_expected.not_to be_valid }
      end

      context 'with defined stages' do
        let(:content) do
          <<~EOS
            include:
              - template: #{template_name}

            stages:
              - build
              - test
              - deploy
              - fuzz

            concrete_build_implemented_by_a_user:
              stage: test
              script: do something
          EOS
        end

        it { is_expected.to be_valid }

        include_examples 'require default stages to be included'
      end

      context 'when API Security template' do
        # The API Security template purposly excludes a stages
        # definition.

        let(:template_name) { 'Security/API-Security.gitlab-ci.yml' }

        context 'with default stages' do
          let(:content) do
            <<~EOS
              include:
                - template: #{template_name}

              concrete_build_implemented_by_a_user:
                stage: test
                script: do something
            EOS
          end

          it { is_expected.not_to be_valid }
        end

        context 'with defined stages' do
          let(:content) do
            <<~EOS
              include:
                - template: #{template_name}

              stages:
                - build
                - test
                - deploy
                - dast

              concrete_build_implemented_by_a_user:
                stage: test
                script: do something
            EOS
          end

          it { is_expected.to be_valid }

          include_examples 'require default stages to be included'
        end
      end
    end
  end
end
