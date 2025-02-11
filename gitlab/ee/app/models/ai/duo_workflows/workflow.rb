# frozen_string_literal: true

module Ai
  module DuoWorkflows
    class Workflow < ::ApplicationRecord
      self.table_name = :duo_workflows_workflows

      belongs_to :user
      belongs_to :project
      has_many :checkpoints, class_name: 'Ai::DuoWorkflows::Checkpoint'
      has_many :checkpoint_writes, class_name: 'Ai::DuoWorkflows::CheckpointWrite'
      has_many :events, class_name: 'Ai::DuoWorkflows::Event'

      validates :status, presence: true
      validates :goal, length: { maximum: 4096 }

      validate :only_known_agent_priviliges

      scope :for_user_with_id!, ->(user_id, id) { find_by!(user_id: user_id, id: id) }
      scope :for_user, ->(user_id) { where(user_id: user_id) }
      scope :for_project, ->(project) { where(project: project) }

      class AgentPrivileges
        READ_WRITE_FILES  = 1
        READ_ONLY_GITLAB  = 2
        READ_WRITE_GITLAB = 3
        RUN_COMMANDS      = 4
        USE_GIT           = 5

        ALL_PRIVILEGES = {
          READ_WRITE_FILES => {
            name: "read_write_files",
            description: "Allow local filesystem read/write access"
          }.freeze,
          READ_ONLY_GITLAB => {
            name: "read_only_gitlab",
            description: "Allow read only access to GitLab APIs"
          }.freeze,
          READ_WRITE_GITLAB => {
            name: "read_write_gitlab",
            description: "Allow write access to GitLab APIs"
          }.freeze,
          RUN_COMMANDS => {
            name: "run_commands",
            description: "Allow running any commands"
          }.freeze,
          USE_GIT => {
            name: "use_git",
            description: "Allow git commits, push and other git commands"
          }.freeze
        }.freeze

        DEFAULT_PRIVILEGES = [
          READ_WRITE_FILES,
          READ_ONLY_GITLAB
        ].freeze
      end

      def only_known_agent_priviliges
        self.agent_privileges ||= AgentPrivileges::DEFAULT_PRIVILEGES

        agent_privileges.each do |privilege|
          unless AgentPrivileges::ALL_PRIVILEGES.key?(privilege)
            errors.add(:agent_privileges, "contains an invalid value #{privilege}")
          end
        end
      end

      state_machine :status, initial: :created do
        event :start do
          transition created: :running
        end

        event :pause do
          transition running: :paused
        end

        event :require_input do
          transition running: :input_required
        end

        event :resume do
          transition [:paused, :input_required] => :running
        end

        event :retry do
          transition [:running, :stopped, :failed] => :running
        end

        event :finish do
          transition running: :finished
        end

        event :drop do
          transition [:created, :running, :paused, :input_required] => :failed
        end

        event :stop do
          transition [:created, :running, :paused, :input_required] => :stopped
        end

        state :created, value: 0
        state :running, value: 1
        state :paused, value: 2
        state :finished, value: 3
        state :failed, value: 4
        state :stopped, value: 5
        state :input_required, value: 6
      end
    end
  end
end
