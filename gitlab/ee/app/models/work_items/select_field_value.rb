# frozen_string_literal: true

module WorkItems
  class SelectFieldValue < ApplicationRecord
    include CustomFieldValue

    belongs_to :custom_field_select_option, class_name: 'Issuables::CustomFieldSelectOption'

    validates :custom_field_select_option, presence: true, uniqueness: { scope: [:work_item_id, :custom_field_id] }
  end
end
