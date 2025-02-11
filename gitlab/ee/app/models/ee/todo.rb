# frozen_string_literal: true

module EE
  module Todo
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      include UsageStatistics
    end

    override :target_url
    def target_url
      return if target.nil?

      case target
      when Vulnerability, Epic
        ::Gitlab::UrlBuilder.build(
          target,
          anchor: note.present? ? ActionView::RecordIdentifier.dom_id(note) : nil
        )
      else
        super
      end
    end
  end
end
