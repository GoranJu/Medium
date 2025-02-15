# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class DevfileFlattener
        include Messages

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.flatten(context)
          context => { devfile: Hash => devfile }

          begin
            flattened_devfile_yaml = Devfile::Parser.flatten(YAML.dump(devfile.deep_stringify_keys))
          rescue Devfile::CliError => e
            return Gitlab::Fp::Result.err(WorkspaceCreateDevfileFlattenFailed.new(details: e.message))
          end

          # NOTE: We do not attempt to rescue any exceptions from YAML.safe_load here because we assume that the
          #       Devfile::Parser gem will not produce invalid YAML. We own the gem, and will fix and add any regression
          #       tests in the gem itself. No need to make this domain code more complex, more coupled, and less
          #       cohesive by unnecessarily adding defensive coding against other code we also own.
          processed_devfile_stringified = YAML.safe_load(flattened_devfile_yaml)

          # symbolize keys for domain logic processing of devfile (to_h is to avoid nil dereference error in RubyMine)
          processed_devfile = processed_devfile_stringified.to_h.deep_symbolize_keys

          processed_devfile[:components] ||= []
          processed_devfile[:commands] ||= []
          processed_devfile[:events] ||= {}
          processed_devfile[:variables] ||= {}

          Gitlab::Fp::Result.ok(context.merge(processed_devfile: processed_devfile))
        end
      end
    end
  end
end
