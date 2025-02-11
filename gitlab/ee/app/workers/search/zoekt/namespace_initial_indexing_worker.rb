# frozen_string_literal: true

module Search
  module Zoekt
    class NamespaceInitialIndexingWorker
      include ApplicationWorker
      include Search::Worker
      prepend ::Geo::SkipSecondary

      data_consistency :always
      idempotent!
      pause_control :zoekt
      urgency :low

      DELAY_INTERVAL = 1.hour.freeze

      def perform(_zoekt_index_id, _options = {}); end
    end
  end
end
