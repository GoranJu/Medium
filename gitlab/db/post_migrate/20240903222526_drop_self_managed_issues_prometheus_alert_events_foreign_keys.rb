# frozen_string_literal: true

class DropSelfManagedIssuesPrometheusAlertEventsForeignKeys < Gitlab::Database::Migration[2.2]
  milestone '17.4'
  disable_ddl_transaction!

  TABLE_NAME = :issues_self_managed_prometheus_alert_events
  EVENTS_FK_NAME = 'fk_rails_f7db2d72eb'
  ISSUES_FK_NAME = 'fk_rails_cc5d88bbb0'

  def up
    with_lock_retries do
      remove_foreign_key_if_exists TABLE_NAME, :prometheus_alert_events,
        column: :self_managed_prometheus_alert_event_id
    end

    with_lock_retries do
      remove_foreign_key_if_exists TABLE_NAME, :issues,
        column: :issue_id
    end
  end

  # Original SQL:
  #
  # ALTER TABLE ONLY issues_self_managed_prometheus_alert_events
  #     ADD CONSTRAINT fk_rails_cc5d88bbb0 FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE;
  #
  # ALTER TABLE ONLY issues_self_managed_prometheus_alert_events
  #     ADD CONSTRAINT fk_rails_f7db2d72eb FOREIGN KEY (self_managed_prometheus_alert_event_id)
  #     REFERENCES self_managed_prometheus_alert_events(id) ON DELETE CASCADE;
  #
  def down
    add_concurrent_foreign_key TABLE_NAME, :self_managed_prometheus_alert_events,
      column: :self_managed_prometheus_alert_event_id,
      name: EVENTS_FK_NAME

    add_concurrent_foreign_key TABLE_NAME, :issues,
      column: :issue_id,
      name: ISSUES_FK_NAME
  end
end
