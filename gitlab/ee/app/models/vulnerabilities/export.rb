# frozen_string_literal: true

module Vulnerabilities
  class Export < Gitlab::Database::SecApplicationRecord
    include Gitlab::Utils::StrongMemoize
    include FileStoreMounter
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    EXPORTER_CLASS = VulnerabilityExports::ExportService
    MAX_EXPORT_DURATION = 24.hours

    self.table_name = "vulnerability_exports"

    belongs_to :project
    belongs_to :group
    belongs_to :author, optional: false, class_name: 'User'
    belongs_to :organization, class_name: 'Organizations::Organization'

    has_many :export_parts, class_name: 'Vulnerabilities::Export::Part', foreign_key: 'vulnerability_export_id',
      dependent: :destroy, inverse_of: :vulnerability_export # rubocop:disable Cop/ActiveRecordDependent -- legacy usage

    mount_file_store_uploader AttachmentUploader

    enum format: {
      csv: 0
    }

    validates :status, presence: true
    validates :format, presence: true
    validates :file, presence: true, if: :finished?
    validate :only_one_exportable

    state_machine :status, initial: :created do
      event :start do
        transition created: :running
      end

      event :finish do
        transition running: :finished
      end

      event :failed do
        transition [:created, :running] => :failed
      end

      event :reset_state do
        transition running: :created
      end

      state :created
      state :running
      state :finished
      state :failed

      before_transition created: :running do |export|
        export.started_at = Time.current
      end

      before_transition any => [:finished, :failed] do |export|
        export.finished_at = Time.current
      end
    end

    def exportable
      project || group || author.security_dashboard
    end

    def exportable=(value)
      case value
      when Project
        make_project_level_export(value)
      when Group
        make_group_level_export(value)
      when InstanceSecurityDashboard
        make_instance_level_export(value)
      else
        raise "Can not assign #{value.class} as exportable"
      end
    end

    def completed?
      finished? || failed?
    end

    def retrieve_upload(_identifier, paths)
      Upload.find_by(model: self, path: paths)
    end

    def export_service
      EXPORTER_CLASS.new(self)
    end

    def schedule_export_deletion
      VulnerabilityExports::ExportDeletionWorker.perform_in(1.hour, id)
    end

    def timed_out?
      created_at < MAX_EXPORT_DURATION.ago
    end

    def uploads_sharding_key
      { organization_id: organization_id }
    end

    private

    def make_project_level_export(project)
      self.project = project
      self.group = nil
      self.organization_id = set_organization(project.namespace)
    end

    def make_group_level_export(group)
      self.group = group
      self.project = nil
      self.organization_id = set_organization(group)
    end

    def make_instance_level_export(security_dashboard)
      self.project = self.group = nil
      self.organization_id = set_organization(security_dashboard.user.namespace)
    end

    def set_organization(namespace)
      namespace.organization_id
    end

    def only_one_exportable
      errors.add(:base, _('Project & Group can not be assigned at the same time')) if project && group
    end
  end
end
