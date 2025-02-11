# frozen_string_literal: true

module RemoteDevelopment
  class WorkspaceContainerResourcesValidator < ActiveModel::EachValidator
    def validate_each(record, attribute, value)
      return true if value == {}

      unless value.is_a?(Hash)
        record.errors.add(attribute, _("must be a hash"))
        return
      end

      limits = value.deep_symbolize_keys.fetch(:limits, nil)
      unless limits.is_a?(Hash)
        record.errors.add(attribute, _("must be a hash containing 'limits' attribute of type hash"))
        return
      end

      requests = value.deep_symbolize_keys.fetch(:requests, nil)
      unless requests.is_a?(Hash)
        record.errors.add(attribute, _("must be a hash containing 'requests' attribute of type hash"))
        return
      end

      resources_validator = KubernetesContainerResourcesValidator.new(attributes: attribute)
      resources_validator.validate_each(record, "#{attribute}_limits", limits)
      resources_validator.validate_each(record, "#{attribute}_requests", requests)
    end
  end
end
