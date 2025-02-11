# frozen_string_literal: true

module GitlabSubscriptions
  class SeatAssignment < ApplicationRecord
    belongs_to :namespace, optional: false
    belongs_to :user, optional: false

    validates :namespace_id, uniqueness: { scope: :user_id }

    scope :by_namespace, ->(namespace) { where(namespace: namespace) }
    scope :by_user, ->(user) { where(user: user) }
    scope :dormant_in_namespace, ->(namespace, cutoff = 90.days.ago) {
      by_namespace(namespace)
        .where('last_activity_on < ? OR (last_activity_on IS NULL AND created_at < ?)', cutoff, cutoff)
    }

    def self.find_by_namespace_and_user(namespace, user)
      by_namespace(namespace).by_user(user).first
    end
  end
end
