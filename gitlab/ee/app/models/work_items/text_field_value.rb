# frozen_string_literal: true

module WorkItems
  class TextFieldValue < ApplicationRecord
    include CustomFieldValue

    MAX_LENGTH = 1024

    validates :custom_field, uniqueness: { scope: [:work_item_id] }
    validates :value, presence: true, length: { maximum: MAX_LENGTH }
  end
end
