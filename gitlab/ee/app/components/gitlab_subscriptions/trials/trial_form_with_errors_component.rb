# frozen_string_literal: true

module GitlabSubscriptions
  module Trials
    class TrialFormWithErrorsComponent < TrialFormComponent
      extend ::Gitlab::Utils::Override

      # @param [Form Params] form params for the form on submission failure

      def initialize(**kwargs)
        super

        @errors = kwargs[:errors]
        @reason = kwargs[:reason]
      end

      private

      attr_reader :errors, :reason

      override :before_form_content
      def before_form_content
        render FormErrorsComponent.new(errors: errors, reason: reason)
      end
    end
  end
end
