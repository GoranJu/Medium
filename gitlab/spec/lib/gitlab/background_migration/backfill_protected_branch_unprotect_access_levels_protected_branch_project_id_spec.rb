# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillProtectedBranchUnprotectAccessLevelsProtectedBranchProjectId,
  feature_category: :source_code_management,
  schema: 20241213141738 do
  include_examples 'desired sharding key backfill job' do
    let(:batch_table) { :protected_branch_unprotect_access_levels }
    let(:backfill_column) { :protected_branch_project_id }
    let(:backfill_via_table) { :protected_branches }
    let(:backfill_via_column) { :project_id }
    let(:backfill_via_foreign_key) { :protected_branch_id }
  end
end
