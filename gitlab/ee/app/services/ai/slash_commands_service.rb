# frozen_string_literal: true

module Ai
  class SlashCommandsService
    CONTROLLER_CONTEXTS = {
      'projects/issues' => :issue,
      'projects/jobs' => :job,
      'projects/security/vulnerabilities' => :vulnerability
    }.freeze

    def self.commands
      {
        base: [
          { name: _('/reset'), description: _('Reset conversation and ignore previous messages.'),
            should_submit: true },
          { name: _('/clear'), description: _('Delete all messages in the current conversation.'),
            should_submit: true },
          { name: _('/help'), description: _('Learn what Duo Chat can do.'), should_submit: true }
        ],
        issue: [
          { name: _('/summarize_comments'),
            description: _('Summarize the comments in the current issue.'),
            should_submit: true }
        ],
        job: [
          { name: _('/troubleshoot'),
            description: _('Troubleshoot failed CI/CD jobs with Root Cause Analysis.'),
            should_submit: true }
        ],
        vulnerability: [
          { name: _('/vulnerability_explain'),
            description: _('Explain current vulnerability.'),
            should_submit: true }
        ]
      }.freeze
    end

    def initialize(user, url)
      @user = user
      @url = url
      @route = parse_route
    end

    def available_commands
      self.class.commands[:base] + context_commands
    end

    private

    def context_commands
      context = determine_context
      return [] unless can_use_context_commands?(context)

      self.class.commands[context] || []
    end

    def can_use_context_commands?(context)
      return false unless has_duo_enterprise_access?

      case context
      when :issue then true
      when :job then can_access_job?
      when :vulnerability then can_access_vulnerability?
      else false
      end
    end

    def has_duo_enterprise_access?
      return false unless @route

      namespace = Namespace.find_by_full_path(@route[:namespace_id])
      namespace && @user&.assigned_to_duo_enterprise?(namespace)
    end

    def can_access_job?
      find_record('jobs')
    end

    def can_access_vulnerability?
      find_record('vulnerabilities')
    end

    def determine_context
      return :unknown unless @route

      CONTROLLER_CONTEXTS[@route[:controller]] || :unknown
    end

    def find_record(resource)
      project = Project.find_by_full_path("#{@route[:namespace_id]}/#{@route[:project_id]}")
      return unless project

      case resource
      when 'jobs'
        project.builds.failed.id_in(@route[:id]).exists?
      when 'vulnerabilities'
        project.vulnerabilities.sast.id_in(@route[:id]).exists?
      end
    end

    def parse_route
      uri = Gitlab::Utils.parse_url(@url)
      return unless uri

      path = uri.path.delete_prefix('/')
      Rails.application.routes.recognize_path(path)
    rescue ActionController::RoutingError
      nil
    end
  end
end
