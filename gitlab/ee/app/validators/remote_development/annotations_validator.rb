# frozen_string_literal: true

module RemoteDevelopment
  class AnnotationsValidator < ActiveModel::EachValidator
    ALPHA_NUMERIC_CHARACTERS = ('a'..'z').to_set + ('A'..'Z').to_set + ('0'..'9').to_set
    MAX_KEY_NAME_LENGTH = 63
    MAX_KEY_PREFIX_LENGTH = 253
    KEY_VALID_CHARACTERS = ALPHA_NUMERIC_CHARACTERS + %w[- _ .].to_set

    def validate_each(record, attribute, value)
      unless value.is_a?(Hash)
        record.errors.add(attribute, _("must be an hash"))
        return
      end

      value.each do |k, v|
        validate_annotation_key(record, attribute, k)
        validate_annotation_value(record, attribute, v)
      end
    end

    private

    def validate_annotation_key(record, attribute, key)
      unless key.is_a?(String)
        record.errors.add(
          attribute,
          format(_("key: %{key} must be a string"), key: key)
        )
        return
      end

      # Valid annotation keys have two segments: an optional prefix and name, separated by a slash (/).
      # https://kubernetes.io/docs/concepts/overview/working-with-objects/annotations/#syntax-and-character-set
      prefix = ""
      name = key
      prefix, _, name = key.partition("/") if key.include?("/") && key[0] != "/"

      unless valid_name?(name)
        record.errors.add(
          attribute,
          format(
            _("key: %{key} must have name component with 63 characters or less, " \
              "and start/end with an alphanumeric character"),
            key: key
          )
        )
      end

      unless valid_prefix?(prefix)
        record.errors.add(
          attribute,
          format(
            _("key: %{key} must have prefix component with 253 characters or less, " \
              "and have a valid DNS subdomain as a prefix"),
            key: key
          )
        )
      end

      return unless prefix.ends_with?("gitlab.com") || prefix.ends_with?("kubernetes.io") || prefix.ends_with?("k8s.io")

      record.errors.add(
        attribute,
        format(_("key: %{key} is reserved for internal usage"), key: key)
      )
    end

    def validate_annotation_value(record, attribute, value)
      return if value.is_a?(String)

      record.errors.add(
        attribute,
        format(_("value: %{value} must be a string"), value: value)
      )
    end

    def valid_name?(name)
      return false if name.empty? || name.length > MAX_KEY_NAME_LENGTH
      return false unless alphanumeric?(name[0]) && alphanumeric?(name[-1])

      name.chars.all? { |char| KEY_VALID_CHARACTERS.include?(char) }
    end

    def valid_prefix?(prefix)
      return true if prefix.empty?
      return false if prefix.length > MAX_KEY_PREFIX_LENGTH
      return false unless alphanumeric?(prefix[0]) && alphanumeric?(prefix[-1])

      labels = prefix.split(".")
      labels.all? { |label| valid_dns_label?(label) }
    end

    def valid_dns_label?(label)
      return false if label.empty? || label.length > 63

      alphanumeric?(label[0]) && alphanumeric?(label[-1]) &&
        label.chars.all? { |char| alphanumeric?(char) || char == '-' }
    end

    def alphanumeric?(char)
      ALPHA_NUMERIC_CHARACTERS.include?(char)
    end
  end
end
