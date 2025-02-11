# frozen_string_literal: true

class GroupDeletionSchedule < ApplicationRecord
  include EE::SecurityOrchestrationHelper # rubocop: disable Cop/InjectEnterpriseEditionModule -- EE-only concern

  belongs_to :group
  belongs_to :deleting_user, foreign_key: 'user_id', class_name: 'User'

  validates :marked_for_deletion_on, presence: true
  validate :excludes_security_policy_projects, if: :group, on: :create

  private

  def excludes_security_policy_projects
    return unless security_configurations_preventing_group_deletion(group).exists?

    errors.add(:base,
      s_('SecurityOrchestration|Group cannot be deleted because it has projects ' \
        'that are linked as a security policy project')
    )
  end
end
