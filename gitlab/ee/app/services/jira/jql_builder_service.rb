# frozen_string_literal: true

module Jira
  class JqlBuilderService
    DEFAULT_SORT = 'created'
    DEFAULT_SORT_DIRECTION = 'DESC'

    # https://confluence.atlassian.com/jirasoftwareserver082/search-syntax-for-text-fields-974359692.html
    JQL_SPECIAL_CHARS = %w[" + . , ; ? | * / % ^ $ # @ [ ] \\].freeze

    # @param [String] jira_project_keys - Jira project keys. Comma separated values
    # @param [Hash] params - Search parameters
    def initialize(jira_project_keys, params = {})
      @jira_project_keys = jira_project_keys
      @search = params[:search]
      @labels = params[:labels]
      @status = params[:status]
      @state  = params[:state]
      @reporter = params[:author_username]
      @assignee = params[:assignee_username]
      @sort = params[:sort] || DEFAULT_SORT
      @sort_direction = params[:sort_direction] || DEFAULT_SORT_DIRECTION
      @vulnerability_ids = params[:vulnerability_ids]
      @issue_ids = params[:issue_ids]
    end

    def execute
      [
        jql_filters,
        order_by
      ].compact_blank.join(' ')
    end

    private

    attr_reader :jira_project_keys, :sort, :sort_direction, :search, :labels, :status, :reporter, :assignee, :state, :vulnerability_ids, :issue_ids

    def jql_filters
      [
        by_project,
        by_labels,
        by_status,
        by_reporter,
        by_assignee,
        by_open_and_closed,
        by_summary_and_description,
        by_vulnerability_ids,
        by_issue_ids
      ].compact.join(' AND ')
    end

    def by_summary_and_description
      return if search.blank?

      escaped_search = remove_special_chars(search)
      %[(summary ~ "#{escaped_search}" OR description ~ "#{escaped_search}")]
    end

    def by_project
      return if jira_project_keys.blank?

      %(project in \(#{escape_quotes(jira_project_keys)}\))
    end

    def by_labels
      return if labels.blank?

      labels.map { |label| %(labels = "#{escape_quotes(label)}") }.join(' AND ')
    end

    def by_status
      return if status.blank?

      %(status = "#{escape_quotes(status)}")
    end

    def order_by
      "order by #{sort} #{sort_direction}"
    end

    def by_reporter
      return if reporter.blank?

      %(reporter = "#{escape_quotes(reporter)}")
    end

    def by_assignee
      return if assignee.blank?

      %(assignee = "#{escape_quotes(assignee)}")
    end

    def by_open_and_closed
      return if state.blank?

      case state
      when 'opened'
        %q(statusCategory != Done)
      when 'closed'
        %q(statusCategory = Done)
      end
    end

    def by_vulnerability_ids
      return if vulnerability_ids.blank?

      vulnerability_ids
        .map { |vulnerability_id| %(description ~ "/-/security/vulnerabilities/#{escape_quotes(vulnerability_id.to_s)}") }
        .join(' OR ')
        .then { |query| "(#{query})" }
    end

    def by_issue_ids
      return if issue_ids.blank?

      issue_ids
        .map { |issue_id| %(id = #{escape_quotes(issue_id.to_s)}) }
        .join(' OR ')
        .then { |query| "(#{query})" }
    end

    def escape_quotes(param)
      param.gsub('\\', '\\\\\\').gsub('"', '\\"')
    end

    def remove_special_chars(param)
      param.delete(JQL_SPECIAL_CHARS.join).downcase.squish
    end
  end
end
