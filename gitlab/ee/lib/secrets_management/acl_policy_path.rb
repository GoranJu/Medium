# frozen_string_literal: true

module SecretsManagement
  class AclPolicyPath
    # Path of this policy
    attr_accessor :path

    # Set of capabilities.
    attr_accessor :capabilities

    # Individual capabilities
    CAP_CREATE = "create"
    CAP_READ = "read"
    CAP_UPDATE = "update"
    CAP_PATCH = "patch"
    CAP_DELETE = "delete"
    CAP_LIST = "list"

    # Parameter restrictions.
    attr_accessor :allowed_parameters
    attr_accessor :denied_parameters, :required_parameters

    def self.build_from_hash(path, object)
      capabilities = Set.new(object["capabilities"]) if object.key?("capabilities")

      ret = new(path, capabilities)
      ret.allowed_parameters = object["allowed_parameters"] if object.key?("allowed_parameters")
      ret.denied_parameters = object["denied_parameters"] if object.key?("denied_parameters")
      ret.required_parameters = Set.new(object["required_parameters"]) if object.key?("required_parameters")

      ret
    end

    def initialize(path, capabilities = [])
      self.path = path

      self.capabilities = Set.new(capabilities)

      # Most callers will not need to set parameter restrictions.
      self.allowed_parameters = {}
      self.denied_parameters = {}
      self.required_parameters = Set.new
    end

    def to_openbao_attributes
      ret = {}
      ret["capabilities"] = capabilities unless capabilities.empty?

      ret["allowed_parameters"] = allowed_parameters unless allowed_parameters.empty?
      ret["denied_parameters"] = denied_parameters unless denied_parameters.empty?
      ret["required_parameters"] = required_parameters unless required_parameters.empty?

      ret
    end
  end
end
