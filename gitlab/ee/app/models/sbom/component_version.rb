# frozen_string_literal: true

module Sbom
  class ComponentVersion < Gitlab::Database::SecApplicationRecord
    include SafelyChangeColumnDefault

    columns_changing_default :organization_id

    belongs_to :component, optional: false
    has_many :occurrences, inverse_of: :component_version
    belongs_to :organization, class_name: 'Organizations::Organization'

    validates :version, presence: true, length: { maximum: 255 }

    scope :by_component_id_and_version, ->(component_id, version) do
      where(component_id: component_id, version: version)
    end
  end
end
