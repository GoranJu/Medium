# frozen_string_literal: true

module EE
  module Resolvers
    module ProjectsResolver
      extend ActiveSupport::Concern
      extend ::Gitlab::Utils::Override

      prepended do
        argument :aimed_for_deletion, GraphQL::Types::Boolean,
          required: false,
          description: 'Return only projects marked for deletion.'
        argument :include_hidden, GraphQL::Types::Boolean,
          required: false,
          description: 'Include hidden projects.'
        argument :marked_for_deletion_on, ::Types::DateType,
          required: false,
          description: 'Date when the project was marked for deletion.'
      end

      private

      override :finder_params
      def finder_params(args)
        super(args)
          .merge(args.slice(:aimed_for_deletion, :include_hidden, :marked_for_deletion_on))
          # Expired SAML session filter disabled for now.
          # Further investigation needed in https://gitlab.com/gitlab-org/gitlab/-/issues/514406
          .merge(filter_expired_saml_session_projects: false)
      end
    end
  end
end
