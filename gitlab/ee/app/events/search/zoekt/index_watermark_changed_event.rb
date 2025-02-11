# frozen_string_literal: true

module Search
  module Zoekt
    class IndexWatermarkChangedEvent < ::Gitlab::EventStore::Event
      def schema
        {
          'type' => 'object',
          'properties' => {
            'index_ids' => { 'type' => 'array', 'items' => { 'type' => 'integer' } },
            'watermark_level' => { 'type' => 'string' }
          }
        }
      end
    end
  end
end
