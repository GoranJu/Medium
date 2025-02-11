# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkDismissService, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :detected, :high_severity, project: project) }
  let(:vulnerability_ids) { [vulnerability.id] }
  let(:comment) { "i prefer lowercase." }
  let(:dismissal_reason) { 'used_in_tests' }

  subject(:service) { described_class.new(user, vulnerability_ids, comment, dismissal_reason) }

  describe '#execute' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user is not authorized to dismiss vulnerabilities from one of the projects' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_vulnerability) { create(:vulnerability, :with_findings, project: other_project) }
      let(:vulnerability_ids) { [vulnerability.id, other_vulnerability.id] }

      it 'raises an error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when the user is authorized' do
      it 'dismisses each vulnerability', :freeze_time do
        service.execute

        vulnerability.reload
        expect(vulnerability).to be_dismissed
        expect(vulnerability.auto_resolved).to be_falsey
        expect(vulnerability.dismissed_by).to eq(user)
        expect(vulnerability.dismissed_at).to eq(Time.current)
      end

      it 'inserts a state transition for each vulnerability' do
        service.execute

        vulnerability.reload
        last_state = vulnerability.state_transitions.last
        expect(last_state.from_state).to eq('detected')
        expect(last_state.to_state).to eq('dismissed')
        expect(last_state.comment).to eq(comment)
        expect(last_state.dismissal_reason).to eq(dismissal_reason)
        expect(last_state.author).to eq(user)
      end

      it 'inserts a system note for each vulnerability' do
        service.execute

        last_note = Note.last

        expect(last_note.noteable).to eq(vulnerability)
        expect(last_note.author).to eq(user)
        expect(last_note.project).to eq(project)
        expect(last_note.namespace_id).to eq(project.project_namespace_id)
        expect(last_note.note).to eq(
          "changed vulnerability status to Dismissed: Used In Tests with the following comment: \"#{comment}\""
        )
        expect(last_note).to be_system
      end

      it 'updates the dismissal reason for each vulnerability read record' do
        service.execute

        reads = Vulnerabilities::Read.by_vulnerabilities(vulnerability_ids)
        expect(reads.pluck(:dismissal_reason)).to match_array([dismissal_reason])
      end

      it 'updates the statistics', :sidekiq_inline do
        _active_vulnerability = create(:vulnerability, :with_finding, :high_severity, project: project)
        Vulnerabilities::Read.update_all(traversal_ids: project.namespace.traversal_ids)

        service.execute

        expect(project.vulnerability_statistic).to be_present
        expect(project.vulnerability_statistic.total).to eq(1)
        expect(project.vulnerability_statistic.critical).to eq(0)
        expect(project.vulnerability_statistic.high).to eq(1)
        expect(project.vulnerability_statistic.medium).to eq(0)
        expect(project.vulnerability_statistic.low).to eq(0)
        expect(project.vulnerability_statistic.unknown).to eq(0)
        expect(project.vulnerability_statistic.letter_grade).to eq('d')
      end

      it 'returns a service response' do
        result = service.execute

        expect(result.payload[:vulnerabilities].count).to eq(vulnerability_ids.count)
      end

      context 'when an error occurs' do
        before do
          allow(Note).to receive(:insert_all!).and_raise(ActiveRecord::RecordNotUnique)
        end

        it 'does not bubble up the error' do
          expect { service.execute }.not_to raise_error
        end

        it 'returns an appropriate service response' do
          result = service.execute

          expect(result).to be_error
          expect(result.errors).to eq(['Could not modify vulnerabilities'])
        end
      end

      context 'when existing vulnerability had previous state changes data' do
        before do
          vulnerability.update!({
            resolved_at: Time.current,
            resolved_by: user,
            confirmed_at: Time.current,
            confirmed_by: user
          })
        end

        it 'cleanses the previous state changes data' do
          service.execute

          vulnerability.reload
          expect(vulnerability.resolved_at).to be_nil
          expect(vulnerability.resolved_by).to be_nil
          expect(vulnerability.confirmed_at).to be_nil
          expect(vulnerability.confirmed_by).to be_nil
        end
      end

      context 'when updating a large # of vulnerabilities' do
        let_it_be(:vulnerabilities) { create_list(:vulnerability, 2, :with_findings, project: project) }
        let_it_be(:vulnerability_ids) { vulnerabilities.map(&:id) }

        before do
          allow_next_instance_of(described_class) do |instance|
            allow(instance).to receive(:authorized_and_ff_enabled_for_all_projects?).and_return(true)
          end
        end

        it 'does not introduce N+1 queries' do
          control = ActiveRecord::QueryRecorder.new do
            described_class.new(user, vulnerability_ids, comment, dismissal_reason).execute
          end

          new_vulnerability = create(:vulnerability, :with_findings)
          vulnerability_ids << new_vulnerability.id

          expect do
            described_class.new(user, vulnerability_ids, comment, dismissal_reason).execute
          end.not_to exceed_query_limit(control)
        end
      end

      context 'when a vulnerability has already been dismissed' do
        let_it_be(:dismissed_vulnerability) { create(:vulnerability, :with_findings, :dismissed, project: project) }
        let(:vulnerability_ids) { [dismissed_vulnerability.id] }

        it 'updates the vulnerability' do
          expect { service.execute }.to change { dismissed_vulnerability.reload.dismissed_at }
        end

        it 'inserts a system note' do
          expect { service.execute }.to change { Note.count }
        end

        it 'inserts a state transition' do
          expect { service.execute }.to change { dismissed_vulnerability.state_transitions.count }
        end

        it 'inserts a new vulnerabilities reads record' do
          service.execute

          reads = Vulnerabilities::Read.by_vulnerabilities(vulnerability_ids)
          expect(reads.pluck(:dismissal_reason)).to match_array([dismissal_reason])
        end

        context 'when called twice with the same arguments' do
          it 'creates 2 valid state transitions' do
            service.execute
            service.execute

            expect(dismissed_vulnerability.reload.state_transitions).to all be_valid
          end
        end
      end
    end
  end
end
