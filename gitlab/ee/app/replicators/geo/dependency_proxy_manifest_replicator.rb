# frozen_string_literal: true

module Geo
  class DependencyProxyManifestReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::DependencyProxy::Manifest
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
