# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::BackgroundMigration::BackfillFreeSharedRunnersMinutesLimit, feature_category: :consumables_cost_management do
  let!(:namespaces) { table(:namespaces) }
  let(:organizations) { table(:organizations) }

  let(:start_id) { namespaces.minimum(:id) }
  let(:end_id) { namespaces.maximum(:id) }
  let(:organization) { table(:organizations).create!(name: 'organization', path: 'organization') }
  let!(:namespace_free_without_limit) do
    namespaces.create!(
      name: 'free_namespace_no_limit',
      path: 'free-namespace-no-limit',
      type: 'User',
      organization_id: organization.id
    )
  end

  let!(:namespace_free_with_limit_1) do
    namespaces.create!(
      name: 'free_namespace_limit_1',
      path: 'free-namespace-limit-1',
      shared_runners_minutes_limit: 400,
      type: 'User',
      organization_id: organization.id
    )
  end

  let!(:namespace_free_with_limit_2) do
    namespaces.create!(
      name: 'free_namespace_limit_2',
      path: 'free-namespace-limit-2',
      shared_runners_minutes_limit: 10_000,
      type: 'User',
      organization_id: organization.id
    )
  end

  let!(:namespace_paid) do
    namespaces.create!(
      name: 'paid_namespace',
      path: 'paid-namespace',
      shared_runners_minutes_limit: 10_000,
      type: 'User',
      organization_id: organization.id
    )
  end

  subject(:migration) do
    described_class.new(
      start_id: start_id,
      end_id: end_id,
      batch_table: :namespaces,
      batch_column: :id,
      sub_batch_size: 1,
      pause_ms: 0,
      connection: ApplicationRecord.connection
    )
  end

  before do
    table(:plans).create!(id: 34, name: 'free')
    table(:plans).create!(id: 1, name: 'ultimate')

    gitlab_subscriptions = table(:gitlab_subscriptions)
    gitlab_subscriptions.create!(
      hosted_plan_id: 34,
      namespace_id: namespace_free_with_limit_1.id)

    gitlab_subscriptions.create!(
      hosted_plan_id: 1,
      namespace_id: namespace_paid.id)
  end

  describe '#perform' do
    it 'backfills shared_runners_minutes_limit for namespaces with a value', :aggregate_failures do
      migration.perform

      expect(namespace_paid.reload.shared_runners_minutes_limit).to eq(10_000)
      expect(namespace_free_without_limit.reload.shared_runners_minutes_limit).to be_nil
      expect(namespace_free_with_limit_1.reload.shared_runners_minutes_limit).to be_nil
      expect(namespace_free_with_limit_2.reload.shared_runners_minutes_limit).to be_nil
    end
  end
end
