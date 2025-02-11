# frozen_string_literal: true

# This class extracts all references found in a piece
# it's either @name or email address or @@role

module Gitlab
  module CodeOwners
    class ReferenceExtractor
      # Not using `Devise.email_regexp` to filter out any chars that an email
      # does not end with and not pinning the email to a start of end of a string.
      EMAIL_REGEXP = /[^@\s]{1,100}@[^@\s]{1,255}(?<!\W)/

      # Pattern used to extract `@user` user references from text.
      # This has a small modification from User.reference_pattern as code owners
      # excludes references prefixed with @@.
      NAME_REGEXP =
        %r{
          (?<![\w@])
          #{Regexp.escape(User.reference_prefix)}
          (?<user>#{Gitlab::PathRegex::FULL_NAMESPACE_FORMAT_REGEX})
        }x

      ROLE_PREFIX = '@@'

      POSSIBLE_ROLES = {
        developer: Gitlab::Access::DEVELOPER,
        maintainer: Gitlab::Access::MAINTAINER,
        owner: Gitlab::Access::OWNER
      }.freeze

      def initialize(text)
        # EE passes an Array to `text` in a few places, so we want to support both
        # here.
        @text = Array(text).join(' ')
      end

      def names
        matches[:names]
      end

      def roles
        matches[:roles]
      end

      def emails
        matches[:emails]
      end

      def references
        return [] if @text.blank?

        @references ||= matches.values.flatten.uniq
      end

      private

      def matches
        @matches ||= {
          emails: @text.scan(EMAIL_REGEXP).flatten.uniq,
          names: @text.scan(NAME_REGEXP).flatten.uniq,
          roles: text_roles.uniq
        }
      end

      def text_roles
        specified_roles = POSSIBLE_ROLES.select do |role, _|
          role_str = ROLE_PREFIX + role.to_s

          # Match @text for `role_str` with whitespace on either side
          # or line start or line ending at the end
          # and an optional single "s" for plurals, ignoring case
          @text.match(/(?:^|\s)#{Regexp.quote(role_str)}s?(\s|$)/i)
        end
        specified_roles.values
      end
    end
  end
end
