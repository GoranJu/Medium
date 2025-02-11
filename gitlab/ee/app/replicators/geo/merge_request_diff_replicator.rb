# frozen_string_literal: true

module Geo
  class MergeRequestDiffReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::MergeRequestDiff
    end

    def carrierwave_uploader
      model_record.external_diff
    end

    private

    # Only external diffs can be checksummed
    override :checksummable?
    def checksummable?
      model_record.stored_externally? && super
    end
  end
end
