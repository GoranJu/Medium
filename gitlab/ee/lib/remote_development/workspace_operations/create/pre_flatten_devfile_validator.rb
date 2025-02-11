# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class PreFlattenDevfileValidator
        include Messages
        include RemoteDevelopmentConstants

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate(context)
          Gitlab::Fp::Result.ok(context)
                .and_then(method(:validate_schema_version))
                .and_then(method(:validate_parent))
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_schema_version(context)
          context => { devfile: Hash => devfile }

          minimum_schema_version = Gem::Version.new(REQUIRED_DEVFILE_SCHEMA_VERSION)
          devfile_schema_version_string = devfile.fetch(:schemaVersion)
          begin
            devfile_schema_version = Gem::Version.new(devfile_schema_version_string)
          rescue ArgumentError
            return err(
              format(_("Invalid 'schemaVersion' '%{schema_version}'"), schema_version: devfile_schema_version_string)
            )
          end

          unless devfile_schema_version == minimum_schema_version
            return err(
              format(
                _("'schemaVersion' '%{given_version}' is not supported, it must be '%{required_version}'"),
                given_version: devfile_schema_version_string,
                required_version: REQUIRED_DEVFILE_SCHEMA_VERSION
              )
            )
          end

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_parent(context)
          context => { devfile: Hash => devfile }

          return err(format(_("Inheriting from 'parent' is not yet supported"))) if devfile[:parent]

          Gitlab::Fp::Result.ok(context)
        end

        # @param [String] details
        # @return [Gitlab::Fp::Result]
        def self.err(details)
          Gitlab::Fp::Result.err(WorkspaceCreatePreFlattenDevfileValidationFailed.new({ details: details }))
        end
        private_class_method :validate_schema_version, :validate_parent, :err
      end
    end
  end
end
