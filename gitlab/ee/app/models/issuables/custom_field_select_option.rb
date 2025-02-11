# frozen_string_literal: true

module Issuables
  class CustomFieldSelectOption < ApplicationRecord
    belongs_to :namespace
    belongs_to :custom_field

    before_validation :copy_namespace_from_custom_field

    validates :namespace, :custom_field, presence: true
    validates :value, presence: true, length: { maximum: 255 },
      uniqueness: { scope: [:custom_field_id], case_sensitive: false }

    private

    def copy_namespace_from_custom_field
      self.namespace ||= custom_field&.namespace
    end
  end
end
