# frozen_string_literal: true

module Users
  class UserMemberRole < ApplicationRecord
    self.table_name = 'user_member_roles'

    belongs_to :member_role
    belongs_to :user

    validates :member_role, presence: true
    validates :user, presence: true, uniqueness: true
  end
end
