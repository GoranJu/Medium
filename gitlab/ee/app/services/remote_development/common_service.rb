# frozen_string_literal: true

require_relative '../../../../lib/gitlab/fp/rop_helpers'

module RemoteDevelopment
  class CommonService
    extend Gitlab::Fp::RopHelpers
    extend ServiceResponseFactory

    # NOTE: This service intentionally does not follow the conventions for object-based service classes as documented in
    #       https://docs.gitlab.com/ee/development/reusing_abstractions.html#service-classes.
    #
    #       See "Minimal service layer" at
    #       https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/remote_development/README.md#minimal-service-layer
    #       for more details on this decision.
    #
    #       See "Service layer code example" at
    #       https://gitlab.com/gitlab-org/gitlab/-/blob/master/ee/lib/remote_development/README.md#service-layer-code-example
    #       for an explanatory code example of invoking and using this class.

    # @param [Class] domain_main_class
    # @param [Hash] domain_main_class_args
    # @param [Symbol, nil] auth_ability - the DeclarativePolicy ability to be checked for authorization.
    #                                     nil must be explicitly passed if no auth check is needed.
    # @param [Object] auth_subject - the DeclarativePolicy subject to be used for the authorization check
    # @param [User] current_user - the current user against which the authorization check will be performed.
    # @return [ServiceResponse]
    def self.execute(domain_main_class:, domain_main_class_args:, auth_ability:, auth_subject: nil, current_user: nil)
      authorize!(
        current_user: current_user,
        auth_ability: auth_ability,
        auth_subject: auth_subject
      )

      raise 'domain_main_class_args must be a Hash' unless domain_main_class_args.is_a?(Hash)

      main_class_method = retrieve_single_public_singleton_method(domain_main_class)

      settings = RemoteDevelopment::Settings.get(RemoteDevelopment::Settings::DefaultSettings.default_settings.keys)
      logger = RemoteDevelopment::Logger.build

      response_hash = domain_main_class.singleton_method(main_class_method).call(
        **domain_main_class_args.merge(settings: settings, logger: logger)
      )

      create_service_response(response_hash)
    end

    # NOTE: Authorization should always already be checked at the GraphQL layer. But we also do this
    #       redundant check at the Service layer, to comply with "defense in depth" secure coding guidelines.
    #       See: https://docs.gitlab.com/ee/development/permissions/authorizations.html#where-should-permissions-be-checked
    # @param [Hash] domain_main_class_args - should contain :current_user entry
    # @param [Symbol, nil] auth_ability - the DeclarativePolicy ability to be checked for authorization
    # @param [Object, nil] auth_subject - the DeclarativePolicy subject to be used for the authorization check
    # @param [User] current_user - the current user against which the authorization check will be performed.
    # @return [void]
    def self.authorize!(auth_ability:, auth_subject:, current_user:)
      return unless auth_ability

      raise "auth_subject is required if auth_ability is passed" unless auth_subject
      raise "current_user is required if auth_ability is passed" unless current_user

      # NOTE: We just raise a regular RuntimeError here instead of Gitlab::Auth::UnauthorizedError or some other
      #       more specific exception, because we want to use fast_spec_helper, and we should never hit this
      #       code anyway if we are properly doing our authorization checks at the GraphQL layer according to
      #       the "defense in depth" secure coding guidelines.
      raise "User is not authorized to perform this action" unless current_user.can?(auth_ability, auth_subject)

      nil
    end

    private_class_method :authorize!
  end
end
