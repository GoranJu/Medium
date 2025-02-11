# frozen_string_literal: true

class AuditEventFinder
  include CreatedAtFilter
  include FinderMethods

  InvalidLevelTypeError = Class.new(StandardError)

  VALID_ENTITY_TYPES = %w[Project User Group Gitlab::Audit::InstanceScope].freeze
  PAGE_THRESHOLD_FOR_OFFSET_OPTIMIZATION = 100

  # Instantiates a new finder
  #
  # @param [Levels::Project, Levels::Group, Levels::Instance] level that results should be scoped to
  # @param [Hash] params for filtering and sorting
  # @option params [String] :entity_type
  # @option params [Integer] :entity_id
  # @option params [DateTime] :created_after from created_at date
  # @option params [DateTime] :created_before to created_at date
  # @option params [String] :sort order by field_direction (e.g. created_asc)
  # @param [Boolean] optimize_offset for enabling finder offset optimization,
  #   still needs feature flag and other settings for offset optimization to kick in
  #
  # @return [AuditEventFinder]
  def initialize(level:, params: {}, optimize_offset: false)
    @level = level
    @params = params
    @optimize_offset = optimize_offset
  end

  # Filters and sorts records
  #
  # @return [AuditEvent::ActiveRecord_Relation]
  def execute
    audit_events = init_collection
    audit_events = by_entity(audit_events)
    audit_events = by_created_at(audit_events)
    audit_events = by_author(audit_events)

    return sort(audit_events) unless should_use_offset_optimization?

    paginate_with_offset_optimization(audit_events)
  end

  def paginate_with_offset_optimization(audit_events)
    audit_events.order(created_at: :desc, id: :desc) # rubocop:disable CodeReuse/ActiveRecord -- Need to order in a deterministic way with tiebreaker

    Gitlab::Pagination::Offset::PaginationWithIndexOnlyScan.new(
      scope: audit_events,
      page: params[:page],
      per_page: params[:per_page]
    ).paginate_with_kaminari
  end

  private

  attr_reader :level, :params

  def init_collection
    raise InvalidLevelTypeError unless valid_level_type?

    level.apply
  end

  def valid_level_type?
    level.class.name.include?('Gitlab::Audit::Levels')
  end

  def by_entity(audit_events)
    return audit_events unless valid_entity_type?

    audit_events = audit_events.by_entity_type(params[:entity_type])

    if valid_entity_username?
      audit_events = audit_events.by_entity_username(params[:entity_username])
    elsif valid_entity_id?
      audit_events = audit_events.by_entity_id(params[:entity_id])
    end

    audit_events
  end

  def by_author(audit_events)
    if valid_author_username?
      audit_events = audit_events.by_author_username(params[:author_username])
    elsif valid_author_id?
      audit_events = audit_events.by_author_id(params[:author_id])
    end

    audit_events
  end

  def sort(audit_events)
    audit_events.order_by(params[:sort])
  end

  def valid_entity_type?
    VALID_ENTITY_TYPES.include? params[:entity_type]
  end

  def valid_entity_id?
    params[:entity_id].to_i.nonzero?
  end

  def valid_author_id?
    params[:author_id].to_i.nonzero?
  end

  def valid_username?(username)
    username.present? && username.length >= User::MIN_USERNAME_LENGTH && username.length <= User::MAX_USERNAME_LENGTH
  end

  def valid_entity_username?
    valid_username?(params[:entity_username])
  end

  def valid_author_username?
    valid_username?(params[:author_username])
  end

  def should_use_offset_optimization?
    @optimize_offset &&
      Feature.enabled?(:audit_events_api_offset_optimization, :instance) &&
      params[:pagination] != 'keyset' &&
      params[:page].to_i > PAGE_THRESHOLD_FOR_OFFSET_OPTIMIZATION
  end
end
