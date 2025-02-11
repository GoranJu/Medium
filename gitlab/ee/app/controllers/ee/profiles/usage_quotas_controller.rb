# frozen_string_literal: true

module EE
  module Profiles
    module UsageQuotasController
      extend ActiveSupport::Concern

      include GoogleAnalyticsCSP
    end
  end
end
