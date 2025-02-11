# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Tools
        module SummarizeComments
          module Prompts
            class Anthropic
              include Concerns::AnthropicPrompt

              def self.prompt(variables)
                conversation = Utils::Prompt.role_conversation(
                  Utils::Prompt.format_conversation(
                    ::Gitlab::Llm::Chain::Tools::SummarizeComments::Executor::PROMPT_TEMPLATE,
                    variables
                  )
                )

                {
                  prompt: conversation,
                  options: { model: ::Gitlab::Llm::Anthropic::Client::CLAUDE_3_5_SONNET }
                }
              end
            end
          end
        end
      end
    end
  end
end
