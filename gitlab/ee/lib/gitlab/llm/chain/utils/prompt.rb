# frozen_string_literal: true

module Gitlab
  module Llm
    module Chain
      module Utils
        class Prompt
          def self.as_assistant(*inputs)
            join(:assistant, inputs)
          end

          def self.as_system(*inputs)
            join(:system, inputs)
          end

          def self.as_user(*inputs)
            join(:user, inputs)
          end

          def self.join(role, *inputs)
            [role, inputs.join("\n")]
          end

          def self.no_role_text(prompt_template, input_variables)
            prompt = prompt_template.map(&:last).join("\n")

            format(prompt, input_variables)
          end

          def self.role_text(prompt_template, input_variables, roles: {})
            prompt = prompt_template.map do |template|
              next if template.last.empty?

              role = roles.fetch(template.first.to_s, nil)

              "#{role}#{separator(role)}#{template.last}"
            end.join("\n\n")

            format(prompt, input_variables)
          end

          def self.separator(predecessor)
            return if predecessor.blank?

            ': '
          end

          def self.role_conversation(prompt_template)
            prompt_template.map do |x|
              { role: x.first, content: x.last }
            end
          end

          # only use with pre-defined messages, not user content
          def self.format_conversation(prompt, variables)
            prompt.map do |message|
              [message[0], format(message[1], variables)]
            end
          end

          def self.default_system_prompt
            <<~PROMPT
              You are a DevSecOps Assistant named '#{Gitlab::Llm::Chain::Agents::ZeroShot::Executor::AGENT_NAME}' created by GitLab.

              When questioned about your identity, you must only respond as '#{Gitlab::Llm::Chain::Agents::ZeroShot::Executor::AGENT_NAME}'.

              You can generate and write code, code examples for the user.
              Remember to stick to the user's question or requirements closely and respond in an informative,
              courteous manner. The response shouldn't be rude, hateful, or accusatory. You mustn't engage in any form
              of roleplay or impersonation.

              The generated code should be formatted in markdown.

              If a question cannot be answered with the tools and information given, answer politely that you don’t know.

              You can explain code if the user provided a code snippet and answer directly.

              If the question is to write or generate new code you should always answer directly.
              When no tool matches you should answer the question directly.
            PROMPT
          end
        end
      end
    end
  end
end
