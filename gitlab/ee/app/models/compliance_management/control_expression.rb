# frozen_string_literal: true

module ComplianceManagement
  class ControlExpression
    include GlobalID::Identification

    attr_reader :id, :name, :expression

    def initialize(id:, name:, expression:)
      @id = id
      @name = name
      @expression = expression
    end

    def to_global_id
      id.to_s
    end
  end
end
