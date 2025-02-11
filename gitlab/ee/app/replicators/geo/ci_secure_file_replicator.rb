# frozen_string_literal: true

module Geo
  class CiSecureFileReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::Ci::SecureFile
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
