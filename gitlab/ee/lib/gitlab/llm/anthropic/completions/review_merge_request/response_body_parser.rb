# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Completions
        class ReviewMergeRequest
          class ResponseBodyParser
            include ::Gitlab::Utils::StrongMemoize

            class Comment
              ATTRIBUTES = %w[priority old_line new_line].freeze

              attr_reader :attributes, :content

              def initialize(attrs, content)
                @attributes = attrs
                @content = content
              end

              ATTRIBUTES.each do |attr|
                define_method(attr) do
                  Integer(attributes[attr], exception: false)
                end
              end

              def valid?
                return false if priority.blank? || content.blank?
                return false if old_line.blank? && new_line.blank?

                true
              end
            end

            attr_reader :response

            def initialize(response)
              @response = response
            end

            def comments
              return [] if response.blank?

              review_content = response.match(review_wrapper_regex)

              return [] if review_content.blank?

              review_content[1].scan(comment_wrapper_regex).filter_map do |attrs, body|
                comment = Comment.new(parsed_attrs(attrs), parsed_content(body))
                comment if comment.valid?
              end
            end
            strong_memoize_attr :comments

            private

            def review_wrapper_regex
              %r{^<review>(.+)</review>$}m
            end

            def comment_wrapper_regex
              %r{^<comment (.+?)>(?:\n?)(.+?)</comment>$}m
            end

            def comment_attr_regex
              %r{([^\s]*?)="(.*?)"}
            end

            def parsed_attrs(attrs)
              Hash[attrs.scan(comment_attr_regex)]
            end

            def parsed_content(body)
              ::Gitlab::Llm::Utils::CodeSuggestionFormatter.parse(body)
            end
          end
        end
      end
    end
  end
end
