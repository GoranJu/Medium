# frozen_string_literal: true

module EE
  module ResourceLabelEvent
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    prepended do
      belongs_to :epic
    end

    class_methods do
      def issuable_attrs
        %i[epic].freeze + super
      end
    end

    override :issuable
    def issuable
      epic || super
    end

    private

    override :label_url_method
    def label_url_method
      return :group_epics_url if issuable.is_a?(Epic)

      super
    end
  end
end
