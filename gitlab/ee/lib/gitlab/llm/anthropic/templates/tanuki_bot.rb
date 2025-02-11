# frozen_string_literal: true

module Gitlab
  module Llm
    module Anthropic
      module Templates
        class TanukiBot
          OPTIONS = {
            max_tokens: 256
          }.freeze
          CONTENT_ID_FIELD = 'ATTRS'

          MAIN_PROMPT = <<~PROMPT
            The following are provided:

            * <question>: question
            * <doc>: GitLab documentation, and a %<content_id>s which will later be converted to URL
            * <example>: example responses

            Given the above:

            If you know the answer, create a final answer.
              * Then return relevant "%<content_id>s" part for references, under the "%<content_id>s:" heading.
            If you don't know the answer: start the response with "Unfortunately, I could not find any documentation", and don't try to make up an answer.

            ---

            Question:
            <question>%<question>s</question>

            Documentation:
            %<content>s

            Example responses:
            <example>
              The documentation for configuring AIUL is present. The relevant sections provide step-by-step instructions on how to configure it in GitLab, including the necessary settings and fields. The documentation covers different installation methods, such as A, B and C.

              %<content_id>s:
              CNT-IDX-a52b551c78c6cc11a603e231b4e789b2
              CNT-IDX-27d7595271143710461371bcef69ed1e
            </example>
            <example>
              Unfortunately, I could not find any documentation related to this question.

              %<content_id>s:
            </example>
            <example>
              Unfortunately, I could not find any documentation about the REFS configuration.
              One documentation mentions that the restriction can be changed by an owner, but it does not specify how to do it.

              %<content_id>s:
              CNT-IDX-a52b551c78c6cc11a603e231b4e789b2
            </example>
          PROMPT

          def self.final_prompt(question:, documents:)
            content = documents_prompt(documents)

            conversation = Gitlab::Llm::Chain::Utils::Prompt.role_conversation([
              Gitlab::Llm::Chain::Utils::Prompt.as_user(main_prompt(question: question,
                content: content)),
              Gitlab::Llm::Chain::Utils::Prompt.as_assistant("FINAL ANSWER:")
            ])

            {
              prompt: conversation,
              options: { model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET }.merge(OPTIONS)
            }
          end

          def self.main_prompt(question:, content:)
            format(
              MAIN_PROMPT,
              question: question,
              content: content,
              content_id: CONTENT_ID_FIELD
            )
          end

          def self.documents_prompt(documents)
            documents.map do |document|
              <<~PROMPT.strip
                <doc>
                CONTENT: #{document[:content]}
                #{CONTENT_ID_FIELD}: CNT-IDX-#{document[:id]}
                </doc>
              PROMPT
            end.join("\n\n")
          end
        end
      end
    end
  end
end
