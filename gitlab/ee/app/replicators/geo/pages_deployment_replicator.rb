# frozen_string_literal: true

module Geo
  class PagesDeploymentReplicator < Gitlab::Geo::Replicator
    include ::Geo::BlobReplicatorStrategy

    def self.model
      ::PagesDeployment
    end

    def carrierwave_uploader
      model_record.file
    end
  end
end
