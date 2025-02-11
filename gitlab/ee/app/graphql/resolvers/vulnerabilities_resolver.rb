# frozen_string_literal: true

module Resolvers
  class VulnerabilitiesResolver < VulnerabilitiesBaseResolver
    include Gitlab::Utils::StrongMemoize
    include LooksAhead
    include Gitlab::InternalEventsTracking

    type Types::VulnerabilityType, null: true

    argument :project_id, [GraphQL::Types::ID],
      required: false,
      description: 'Filter vulnerabilities by project.'

    argument :report_type, [Types::VulnerabilityReportTypeEnum],
      required: false,
      description: 'Filter vulnerabilities by report type.'

    argument :severity, [Types::VulnerabilitySeverityEnum],
      required: false,
      description: 'Filter vulnerabilities by severity.'

    argument :state, [Types::VulnerabilityStateEnum],
      required: false,
      description: 'Filter vulnerabilities by state.'

    argument :owasp_top_ten, [Types::VulnerabilityOwaspTop10Enum],
      required: false,
      as: :owasp_top_10,
      description: 'Filter vulnerabilities by OWASP Top 10 category. Wildcard value "NONE" also supported ' \
                   'and it cannot be combined with other OWASP top 10 values.'

    argument :identifier_name, GraphQL::Types::String,
      required: false,
      description: 'Filter vulnerabilities by identifier name. Applicable on group ' \
                   'level when feature flag `vulnerability_filtering_by_identifier_group` is enabled. ' \
                   'Ignored when applied on instance security dashboard queries.'

    argument :scanner, [GraphQL::Types::String],
      required: false,
      description: 'Filter vulnerabilities by VulnerabilityScanner.externalId.'

    argument :scanner_id, [::Types::GlobalIDType[::Vulnerabilities::Scanner]],
      required: false,
      description: 'Filter vulnerabilities by scanner ID.'

    argument :sort, Types::VulnerabilitySortEnum,
      required: false,
      default_value: 'severity_desc',
      description: 'List vulnerabilities by sort order.'

    argument :has_resolution, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have been resolved on default branch.'

    argument :has_ai_resolution, GraphQL::Types::Boolean,
      required: false,
      experiment: { milestone: '17.5' },
      description: 'Returns only the vulnerabilities which can likely be resolved by GitLab Duo Vulnerability Resolution. Requires the `vulnerability_report_vr_filter` feature flag to be enabled, otherwise the argument is ignored.'

    argument :has_issues, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have linked issues.'

    argument :has_merge_request, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have linked merge requests.'

    argument :image, [GraphQL::Types::String],
      required: false,
      description: "Filter vulnerabilities by location image. When this filter is present, "\
                   "the response only matches entries for a `reportType` "\
                   "that includes #{::Vulnerabilities::Finding::REPORT_TYPES_WITH_LOCATION_IMAGE.map { |type| "`#{type}`" }.join(', ')}."

    argument :cluster_id, [::Types::GlobalIDType[::Clusters::Cluster]],
      prepare: ->(ids, _) { ids.map(&:model_id) },
      required: false,
      description: "Filter vulnerabilities by `cluster_id`. Vulnerabilities with a `reportType` "\
                   "of `cluster_image_scanning` are only included with this filter."

    argument :cluster_agent_id, [::Types::GlobalIDType[::Clusters::Agent]],
      prepare: ->(ids, _) { ids.map(&:model_id) },
      required: false,
      description: "Filter vulnerabilities by `cluster_agent_id`. Vulnerabilities with a `reportType` "\
                   "of `cluster_image_scanning` are only included with this filter."

    argument :dismissal_reason, [Types::Vulnerabilities::DismissalReasonEnum],
      required: false,
      description: "Filter by dismissal reason. Only dismissed Vulnerabilities will be included with the filter."

    argument :has_remediations, GraphQL::Types::Boolean,
      required: false,
      description: 'Returns only the vulnerabilities which have remediations.'

    def resolve_with_lookahead(**args)
      return Vulnerability.none unless vulnerable

      validate_filters(args)
      track_event

      args[:scanner_id] = resolve_gids(args[:scanner_id], ::Vulnerabilities::Scanner) if args[:scanner_id]

      vulnerabilities(args)
        .with_findings_scanner_and_identifiers
    end

    def unconditional_includes
      [{ vulnerability: [:findings, :vulnerability_read] }]
    end

    def preloads
      {
        has_remediations: { vulnerability: { findings: :remediations } },
        merge_request: { vulnerability: :merge_requests },
        state_comment: { vulnerability: :state_transitions },
        state_transitions: { vulnerability: :state_transitions },
        false_positive: { vulnerability: { findings: :vulnerability_flags } },
        representation_information: { vulnerability: :representation_information }
      }
    end

    private

    def vulnerabilities(params)
      finder_params = params.merge(before_severity: before_severity, after_severity: after_severity)
      finder_params.delete(:has_ai_resolution) unless resolve_with_duo_filtering_enabled?

      apply_lookahead(::Security::VulnerabilityReadsFinder.new(vulnerable, finder_params).execute.as_vulnerabilities)
    end

    def resolve_with_duo_filtering_enabled?
      actor = case vulnerable
              when ::InstanceSecurityDashboard
                current_user
              when Project
                vulnerable.group
              else
                vulnerable
              end

      Feature.enabled?(:vulnerability_report_vr_filter, actor)
    end

    def after_severity
      severity_from_cursor(:after)
    end

    def before_severity
      severity_from_cursor(:before)
    end

    def severity_from_cursor(cursor)
      cursor_value = current_arguments && current_arguments[cursor]

      return unless cursor_value

      decoded_cursor = Base64.urlsafe_decode64(cursor_value)

      Gitlab::Json.parse(decoded_cursor)['severity']
    rescue ArgumentError, JSON::ParserError
    end

    def current_arguments
      context[:current_arguments]
    end

    def track_event
      track_internal_event(
        "called_vulnerability_api",
        user: current_user,
        project: vulnerable.is_a?(::Project) ? vulnerable : nil,
        namespace: vulnerable.is_a?(::Group) ? vulnerable : nil,
        additional_properties: {
          label: 'graphql'
        }
      )
    end
  end
end
