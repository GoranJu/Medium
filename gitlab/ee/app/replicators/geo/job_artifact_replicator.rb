# frozen_string_literal: true

module Geo
  class JobArtifactReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Ci::JobArtifact
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
