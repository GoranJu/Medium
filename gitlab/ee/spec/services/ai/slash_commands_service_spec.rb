# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::SlashCommandsService, feature_category: :duo_chat do
  let(:user) { create(:user) }

  shared_examples 'returns only base commands' do
    it 'returns only base commands' do
      expect(available_commands).to match_array(described_class.commands[:base])
    end
  end

  describe '#available_commands' do
    subject(:available_commands) { described_class.new(user, url).available_commands }

    context 'with unknown context' do
      let(:url) { 'https://gitlab.com/some/unknown/path' }
      let(:namespace) { create(:namespace) }

      before do
        allow(Namespace).to receive(:find_by_full_path).and_return(namespace)
        allow(Rails.application.routes).to receive(:recognize_path).and_return({ controller: 'unknown/controller' })
      end

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).with(namespace).and_return(true)
        end

        it_behaves_like 'returns only base commands'
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).with(namespace).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end

      context 'when user is not authorized' do
        let(:user) { nil }

        it_behaves_like 'returns only base commands'
      end
    end

    context 'when ActionController::RoutingError is raised' do
      let(:url) { 'https://gitlab.com/' }

      before do
        allow(Rails.application.routes).to receive(:recognize_path).and_raise(ActionController::RoutingError.new('Err'))
      end

      it_behaves_like 'returns only base commands'

      it 'catches the RoutingError' do
        expect { available_commands }.not_to raise_error
      end
    end

    context 'with issue context' do
      let_it_be(:project) { create(:project) }
      let(:issue) { create(:issue, project: project) }
      let(:url) { Gitlab::Routing.url_helpers.project_issue_url(project, issue) }

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
        end

        it 'returns base commands and issue-specific commands' do
          expected_commands = described_class.commands[:base] + described_class.commands[:issue]
          expect(available_commands).to match_array(expected_commands)
        end
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end
    end

    context 'with job context' do
      let_it_be(:project) { create(:project) }
      let(:job) { create(:ci_build, :failed, project: project) }
      let(:url) { Gitlab::Routing.url_helpers.project_job_url(project, job) }

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
        end

        context 'when job is failed' do
          it 'returns base commands and job-specific commands' do
            expected_commands = described_class.commands[:base] + described_class.commands[:job]
            expect(available_commands).to match_array(expected_commands)
          end
        end

        context 'when job is not failed' do
          let(:job) { create(:ci_build, project: project) }

          it_behaves_like 'returns only base commands'
        end
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end
    end

    context 'with vulnerability context' do
      let_it_be(:project) { create(:project) }
      let(:vulnerability) { create(:vulnerability, :detected, :sast, project: project) }
      let(:url) { Gitlab::Routing.url_helpers.project_security_vulnerability_url(project, vulnerability) }

      context 'when user has Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(true)
        end

        context 'when vulnerability is SAST' do
          it 'returns base commands and vulnerability-specific commands' do
            expected_commands = described_class.commands[:base] + described_class.commands[:vulnerability]
            expect(available_commands).to match_array(expected_commands)
          end
        end

        context 'when vulnerability is not SAST' do
          let(:vulnerability) { create(:vulnerability, :detected, :container_scanning, project: project) }

          it_behaves_like 'returns only base commands'
        end
      end

      context 'when user does not have Duo Enterprise access' do
        before do
          allow(user).to receive(:assigned_to_duo_enterprise?).and_return(false)
        end

        it_behaves_like 'returns only base commands'
      end
    end

    context 'with invalid URL' do
      let(:url) { 'invalid_url' }

      it_behaves_like 'returns only base commands'
    end

    context 'with nil URL' do
      let(:url) { nil }

      it_behaves_like 'returns only base commands'
    end
  end
end
