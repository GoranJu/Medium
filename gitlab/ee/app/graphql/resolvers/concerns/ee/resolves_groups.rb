# frozen_string_literal: true

module EE
  module ResolvesGroups
    extend ActiveSupport::Concern

    private

    def unconditional_includes
      [:saml_provider]
    end
  end
end
