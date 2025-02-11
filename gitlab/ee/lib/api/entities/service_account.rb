# frozen_string_literal: true

module API
  module Entities
    class ServiceAccount < UserSafe
      expose :email, documentation: { type: 'string', example: 'service_account@example.com' }
    end
  end
end
