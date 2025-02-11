# frozen_string_literal: true

module Resolvers
  module Vulnerabilities
    class IdentifierSearchResolver < BaseResolver
      include Gitlab::Graphql::Authorize::AuthorizeResource

      MAX_VULNERABILITY_COUNT_GROUP_SUPPORT = 20_000

      authorize :read_security_resource

      type [GraphQL::Types::String], null: false

      argument :name, GraphQL::Types::String,
        required: true,
        description: 'Search identifier by name. Substring or partial match search is supported and ' \
          'argument should be greater than 3 characters.'

      def resolve(**args)
        authorize!

        return unless args[:name].present?

        validate_args(args)

        group_allowed_for_search?

        if object.is_a?(::Project)
          ::Vulnerabilities::Identifier.search_identifier_name(
            object.project_id, args[:name])
        elsif object.is_a?(::Group)
          ::Vulnerabilities::Identifier.search_identifier_name_in_group(
            object, args[:name])
        end
      end

      private

      def validate_args(args)
        if object.is_a?(::Group) && Feature.disabled?(:vulnerability_filtering_by_identifier_group, object,
          type: :beta)
          raise ::Gitlab::Graphql::Errors::ArgumentError,
            'Feature flag `vulnerability_filtering_by_identifier_group` is disabled for the group.'
        end

        return unless args[:name].length < 3

        raise ::Gitlab::Graphql::Errors::ArgumentError,
          'Name should be greater than 3 characters.'
      end

      def authorize!
        Ability.allowed?(context[:current_user], :read_security_resource, object) ||
          raise_resource_not_available_error!
      end

      def group_allowed_for_search?
        return unless object.is_a?(Group)

        vulnerability_count = ::Security::ProjectStatistics.sum_vulnerability_count_for_group(object)
        allowed = vulnerability_count <= MAX_VULNERABILITY_COUNT_GROUP_SUPPORT

        raise ::Gitlab::Graphql::Errors::ArgumentError, 'Group has more than 20k vulnerabilities.' unless allowed
      end
    end
  end
end
