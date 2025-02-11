# frozen_string_literal: true

class ReindexWikisToUpdateIntegerWithLongType < Elastic::Migration
  def migrate
    Search::Elastic::ReindexingTask.create!(targets: %w[Wiki], options: { skip_pending_migrations_check: true })
  end

  def completed?
    true
  end
end
