# frozen_string_literal: true

module RemoteDevelopment
  class DefaultRuntimeClassValidator < ActiveModel::EachValidator
    ALPHA_NUMERIC_CHARACTERS = ('a'..'z').to_set + ('0'..'9').to_set
    MAX_LENGTH = 253
    VALID_CHARACTERS = ALPHA_NUMERIC_CHARACTERS + %w[- .].to_set

    def validate_each(record, attribute, value)
      unless value.is_a?(String)
        record.errors.add(attribute, _("must be a string"))
        return
      end

      return if value.empty?

      record.errors.add(attribute, "must be 253 characters or less") if value.length > MAX_LENGTH
      record.errors.add(attribute, "must start and end with an alphanumeric character") unless valid_start_end?(value)

      return if valid_characters?(value)

      record.errors.add(attribute, "must contain only lowercase alphanumeric characters, '-', and '.'")
    end

    private

    def valid_start_end?(value)
      alphanumeric?(value[0]) && alphanumeric?(value[-1])
    end

    def valid_characters?(value)
      value.chars.all? { |char| VALID_CHARACTERS.include?(char) }
    end

    def alphanumeric?(char)
      ALPHA_NUMERIC_CHARACTERS.include?(char)
    end
  end
end
