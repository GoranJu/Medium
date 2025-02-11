# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Vulnerabilities::BulkSeverityOverrideService, feature_category: :vulnerability_management do
  let_it_be(:user) { create(:user) }
  let_it_be(:namespace) { create(:namespace) }
  let_it_be(:project) { create(:project, namespace: namespace) }
  let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :high_severity, project: project) }
  let(:vulnerability_ids) { [vulnerability.id] }
  let(:comment) { "Severity needs to be updated." }
  let(:new_severity) { 'critical' }

  subject(:service) { described_class.new(user, vulnerability_ids, comment, new_severity) }

  describe '#execute' do
    before_all do
      project.add_maintainer(user)
    end

    before do
      stub_licensed_features(security_dashboard: true)
    end

    context 'when the user is not authorized to update vulnerabilities from one of the projects' do
      let_it_be(:other_project) { create(:project) }
      let_it_be(:other_vulnerability) { create(:vulnerability, :with_findings, project: other_project) }
      let(:vulnerability_ids) { [vulnerability.id, other_vulnerability.id] }

      it 'raises an error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when vulnerability_severity_override feature flag is disabled' do
      before do
        stub_feature_flags(vulnerability_severity_override: false)
      end

      it 'raises an error' do
        expect { service.execute }.to raise_error(Gitlab::Access::AccessDeniedError)
      end
    end

    context 'when the user is authorized' do
      it 'updates the severity for each vulnerability', :freeze_time do
        service.execute

        vulnerability.reload
        expect(vulnerability.severity).to eq(new_severity)
        expect(vulnerability.updated_at).to eq(Time.current)
      end

      it 'updates the severity for each vulnerability finding' do
        service.execute

        expect(vulnerability.finding.reload.severity).to eq(new_severity)
      end

      it 'inserts a severity override record for each vulnerability' do
        service.execute

        vulnerability.reload
        last_override = Vulnerabilities::SeverityOverride.last
        expect(last_override.vulnerability_id).to eq(vulnerability.id)
        expect(last_override.original_severity).to eq('high')
        expect(last_override.new_severity).to eq(new_severity)
        expect(last_override.author).to eq(user)
      end

      it 'returns a service response' do
        result = service.execute

        expect(result.payload[:vulnerabilities].count).to eq(vulnerability_ids.count)
      end

      context 'when an error occurs during update' do
        before do
          allow(Vulnerabilities::SeverityOverride).to receive(:insert_all!).and_raise(ActiveRecord::RecordNotUnique)
        end

        it 'returns an appropriate service response' do
          result = service.execute

          expect(result).to be_error
          expect(result.errors).to eq(['Could not modify vulnerabilities'])
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
            described_class.new(user, vulnerability_ids, comment, new_severity).execute
          end

          new_vulnerability = create(:vulnerability, :with_findings)
          vulnerability_ids << new_vulnerability.id

          expect do
            described_class.new(user, vulnerability_ids, comment, new_severity).execute
          end.not_to exceed_query_limit(control)
        end
      end

      context 'when a vulnerability already has the new severity' do
        let_it_be(:vulnerability) { create(:vulnerability, :with_findings, :critical_severity, project: project) }

        it 'does not create severity override record' do
          expect { service.execute }.not_to change { Vulnerabilities::SeverityOverride.count }
        end

        it 'does not update a vulnerability' do
          expect { service.execute }.not_to change { vulnerability.reload.updated_at }
        end
      end
    end
  end
end
