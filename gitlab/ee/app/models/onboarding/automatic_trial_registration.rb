# frozen_string_literal: true

module Onboarding
  class AutomaticTrialRegistration < TrialRegistration
    extend ::Gitlab::Utils::Override

    # string methods

    override :product_interaction
    def self.product_interaction
      'SaaS Trial - defaulted'
    end

    override :company_form_type
    def self.company_form_type
      'registration'
    end

    # predicate methods

    override :show_company_form_illustration?
    def self.show_company_form_illustration?
      false
    end
  end
end
