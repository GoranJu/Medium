# frozen_string_literal: true

module Gitlab
  module Llm
    module Templates
      class ReviewMergeRequest
        include Gitlab::Llm::Chain::Concerns::AnthropicPrompt
        include Gitlab::Utils::StrongMemoize

        SYSTEM_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_system(
          <<~PROMPT.chomp
            You are an experienced software developer tasked with reviewing code changes made by your colleague in a GitLab merge request. Your goal is to review the changes thoroughly and offer constructive and yet concise feedback if required.
          PROMPT
        )
        USER_MESSAGE = Gitlab::Llm::Chain::Utils::Prompt.as_user(
          <<~PROMPT.chomp
            First, you will be given a filename and the git diff of that file. This diff contains the changes made in the MR that you need to review.

            Here is the filename of the git diff:

            <filename>
            %{new_path}
            </filename>

            Here is the git diff you need to review:

            <git_diff>
            %{diff_lines}
            </git_diff>

            To properly review this MR, follow these steps:

            1. Parse the git diff:
               - Each `<line>` tag inside of the `<git_diff>` tag represents a line in git diff
               - `old_line` attribute in `<line>` tag represents the old line number before the change
               - `old_line` will be empty if the line is a newly added line
               - `new_line` attribute  in `<line>` tag represents the new line number after the change
               - `new_line` will be empty if the line is a deleted line
               - Unchanged lines will have both `old_line` and `new_line`, but the line number may have changed if any changes were made above the line

            2. Analyze the changes carefully, strictly focus on the following criteria:
               - Code correctness and functionality
               - Code efficiency and performance impact
               - Potential security vulnerabilities like SQL injection, XSS, etc.
               - Potential bugs or edge cases that may have been missed
               - Do not comment on documentations

            3. Formulate your comments:
               - Determine the most appropriate line for your comment
               - When you notice multiple issues on the same line, leave only one comment on that line and list your issues together. List comments from highest in priority to the lowest.
               - Assign each comment a priority from 1 to 3:
                 - Priority 1: Not important
                 - Priority 2: Helpful but can be ignored
                 - Priority 3: Important, helpful and required

            4. Format your comments:
               - Wrap each comment in a <comment> element
               - Include a `priority` attribute with the assigned priority (1, 2, or 3)
               - Include the `old_line` and `new_line` attributes exactly as they appear in the chosen `<line>` tag for the comment
               - When suggesting a change, use the following format:
                 <from>
                   [existing lines that you are suggesting to change]
                 </from>
                 <to>
                   [your suggestion]
                 </to>
                 - <from> tag must be identical to the lines as they appear in the diff, including any leading spaces or tabs
                 - <to> tag must contain your suggestion
                 - Opening and closing `<from>` and `<to>` tags should not be on the same line as the content
                 - When making suggestions, always maintain the exact indentation as shown in the original diff. The suggestion should match the indentation of the line you are commenting on precisely, as it will be applied directly in place of the existing line.
                 - Your suggestion must only include the lines that are actually changing from the existing lines

               - Do not include any code suggestions when you are commenting on a deleted line since suggestions cannot be applied on deleted lines
               - Wrap your entire response in `<review></review>` tag.
               - Just return `<review></review>` as your entire response, if the change is acceptable

            Remember to only focus on substantive feedback that will genuinely improve the code or prevent potential issues. Do not nitpick or comment on trivial matters.

            Begin your review now.
          PROMPT
        )

        def initialize(new_path, raw_diff, hunk)
          @new_path = new_path
          @raw_diff = raw_diff
          @hunk = hunk
        end

        def to_prompt
          {
            messages: Gitlab::Llm::Chain::Utils::Prompt.role_conversation(
              Gitlab::Llm::Chain::Utils::Prompt.format_conversation([USER_MESSAGE], variables)
            ),
            system: Gitlab::Llm::Chain::Utils::Prompt.no_role_text([SYSTEM_MESSAGE], {}),
            model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET
          }
        end

        def variables
          {
            new_path: new_path,
            diff_lines: xml_diff_lines
          }
        end

        private

        def xml_diff_lines
          lines = Gitlab::Diff::Parser.new.parse(raw_diff.lines)

          lines.map do |line|
            # NOTE: We are passing in diffs without the prefixes as the LLM seems to get confused sometimes and thinking
            # that's a part of the actual content.
            %(<line old_line="#{line.old_line}" new_line="#{line.new_line}">#{line.text(prefix: false)}</line>)
          end.join("\n")
        end

        attr_reader :new_path, :raw_diff, :hunk
      end
    end
  end
end
