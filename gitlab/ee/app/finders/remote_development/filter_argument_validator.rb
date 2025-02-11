# frozen_string_literal: true

module RemoteDevelopment
  class FilterArgumentValidator
    #
    # Validate filter arguments against the given types.
    #
    # @param [Hash<String, Type>] types Types of arguments passed in the filter
    # @param [Hash] filter_arguments Filter arguments to be validated
    #
    # @return [Boolean] Whether the arguments are valid
    #
    def self.validate_filter_argument_types!(types, filter_arguments)
      errors = []

      filter_arguments.each do |argument_name, argument|
        type = types[argument_name.to_sym]
        errors << "'#{argument_name}' must be an Array of '#{type}'" unless argument.is_a?(Array) && argument.all?(type)
      end

      raise errors.join(", ") if errors.present?
    end

    #
    # Validate that at least one filter argument is provided.
    #
    # @param [Hash] **filter_arguments Filter arguments to be validated
    #
    # @return [Boolean] Whether at least one filter argument is provided
    #
    def self.validate_at_least_one_filter_argument_provided!(**filter_arguments)
      no_filter_arguments_provided = filter_arguments.values.flatten.empty?
      raise ArgumentError, "At least one filter argument must be provided" if no_filter_arguments_provided
    end
  end
end
