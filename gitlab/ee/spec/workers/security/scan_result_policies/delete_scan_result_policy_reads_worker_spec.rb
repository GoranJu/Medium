# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Security::ScanResultPolicies::DeleteScanResultPolicyReadsWorker, "#perform", feature_category: :security_policy_management do
  let_it_be(:read) { create(:scan_result_policy_read) }

  subject(:perform) { described_class.new.perform(configuration_id) }

  context 'with existing configuration' do
    let(:configuration_id) { read.security_orchestration_policy_configuration.id }

    specify do
      expect { perform }.to change { Security::ScanResultPolicyRead.exists?(read.id) }.from(true).to(false)
    end
  end

  context 'with non-existing configuration' do
    let(:configuration_id) { non_existing_record_id }

    specify do
      expect { perform }.not_to change { Security::ScanResultPolicyRead.exists?(read.id) }.from(true)
    end
  end
end
