# frozen_string_literal: true

module Geo
  class DependencyProxyBlobReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::DependencyProxy::Blob
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
