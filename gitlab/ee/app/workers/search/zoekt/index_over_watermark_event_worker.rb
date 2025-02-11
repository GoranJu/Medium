# frozen_string_literal: true

module Search
  module Zoekt
    class IndexOverWatermarkEventWorker
      include Gitlab::EventStore::Subscriber
      include Search::Zoekt::EventWorker
      prepend ::Geo::SkipSecondary

      deduplicate :until_executed
      idempotent!

      # See: https://gitlab.com/gitlab-org/gitlab/-/merge_requests/168462
      def handle_event(event); end
    end
  end
end
