# frozen_string_literal: true

module RemoteDevelopment
  module WorkspaceOperations
    module Create
      class PostFlattenDevfileValidator
        include CreateConstants
        include Messages

        # Since this is called after flattening the devfile, we can safely assume that it has valid syntax
        # as per devfile standard. If you are validating something that is not available across all devfile versions,
        # add additional guard clauses.
        # Devfile standard only allows name/id to be of the format /'^[a-z0-9]([-a-z0-9]*[a-z0-9])?$'/
        # Hence, we do no need to restrict the prefix `gl_`.
        # However, we do that for the 'variables' in the processed_devfile since they do not have any such restriction
        RESTRICTED_PREFIX = "gl-"

        # Currently, we only support 'container' and 'volume' type components.
        # For container components, ensure no endpoint name starts with restricted_prefix
        UNSUPPORTED_COMPONENT_TYPES = %i[kubernetes openshift image].freeze

        # Currently, we only support 'exec' and 'apply' for validation
        SUPPORTED_COMMAND_TYPES = %i[exec apply].freeze

        # Currently, we only support `preStart` events
        SUPPORTED_EVENTS = %i[preStart].freeze

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate(context)
          Gitlab::Fp::Result.ok(context)
                .and_then(method(:validate_projects))
                .and_then(method(:validate_root_attributes))
                .and_then(method(:validate_components))
                .and_then(method(:validate_containers))
                .and_then(method(:validate_endpoints))
                .and_then(method(:validate_commands))
                .and_then(method(:validate_events))
                .and_then(method(:validate_variables))
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_projects(context)
          context => { processed_devfile: Hash => processed_devfile }

          return err(_("'starterProjects' is not yet supported")) if processed_devfile[:starterProjects]
          return err(_("'projects' is not yet supported")) if processed_devfile[:projects]

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_root_attributes(context)
          context => { processed_devfile: Hash => processed_devfile }

          return err(_("Attribute 'pod-overrides' is not yet supported")) if processed_devfile.dig(:attributes,
            :"pod-overrides")

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_components(context)
          context => { processed_devfile: Hash => processed_devfile }

          components = processed_devfile[:components]

          return err(_("No components present in devfile")) if components.blank?

          injected_main_components = components.select do |component|
            component.dig(:attributes, MAIN_COMPONENT_INDICATOR_ATTRIBUTE.to_sym)
          end

          if injected_main_components.empty?
            return err(
              format(_("No component has '%{attribute}' attribute"), attribute: MAIN_COMPONENT_INDICATOR_ATTRIBUTE)
            )
          end

          if injected_main_components.length > 1
            return err(
              format(
                _("Multiple components '%{name}' have '%{attribute}' attribute"),
                name: injected_main_components.pluck(:name), # rubocop:disable CodeReuse/ActiveRecord -- this pluck isn't from ActiveRecord, it's from ActiveSupport
                attribute: MAIN_COMPONENT_INDICATOR_ATTRIBUTE
              )
            )
          end

          components_all_have_names = components.all? { |component| component[:name].present? }
          return err(_("Components must have a 'name'")) unless components_all_have_names

          components.each do |component|
            component_name = component.fetch(:name)
            # Ensure no component name starts with restricted_prefix
            if component_name.downcase.start_with?(RESTRICTED_PREFIX)
              return err(format(
                _("Component name '%{component}' must not start with '%{prefix}'"),
                component: component_name,
                prefix: RESTRICTED_PREFIX
              ))
            end

            UNSUPPORTED_COMPONENT_TYPES.each do |unsupported_component_type|
              if component[unsupported_component_type]
                return err(format(_("Component type '%{type}' is not yet supported"), type: unsupported_component_type))
              end
            end

            return err(_("Attribute 'container-overrides' is not yet supported")) if component.dig(
              :attributes, :"container-overrides")

            return err(_("Attribute 'pod-overrides' is not yet supported")) if component.dig(:attributes,
              :"pod-overrides")
          end

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_containers(context)
          context => { processed_devfile: Hash => processed_devfile }

          components = processed_devfile.fetch(:components)

          components.each do |component|
            container = component[:container]
            next unless container

            if container[:dedicatedPod]
              return err(
                format(
                  _("Property 'dedicatedPod' of component '%{name}' is not yet supported"),
                  name: component.fetch(:name)
                )
              )
            end
          end

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_endpoints(context)
          context => { processed_devfile: Hash => processed_devfile }

          components = processed_devfile.fetch(:components)

          err_result = nil

          components.each do |component|
            next unless component.dig(:container, :endpoints)

            container = component.fetch(:container)

            container.fetch(:endpoints).each do |endpoint|
              endpoint_name = endpoint.fetch(:name)
              next unless endpoint_name.downcase.start_with?(RESTRICTED_PREFIX)

              err_result = err(
                format(
                  _("Endpoint name '%{endpoint}' of component '%{component}' must not start with '%{prefix}'"),
                  endpoint: endpoint_name,
                  component: component.fetch(:name),
                  prefix: RESTRICTED_PREFIX
                )
              )
            end
          end

          return err_result if err_result

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_commands(context)
          context => { processed_devfile: Hash => processed_devfile }

          # Ensure no command name starts with restricted_prefix
          processed_devfile.fetch(:commands).each do |command|
            command_id = command.fetch(:id)
            if command_id.downcase.start_with?(RESTRICTED_PREFIX)
              return err(
                format(
                  _("Command id '%{command}' must not start with '%{prefix}'"),
                  command: command_id,
                  prefix: RESTRICTED_PREFIX
                )
              )
            end

            # Ensure no command is referring to a component with restricted_prefix
            SUPPORTED_COMMAND_TYPES.each do |supported_command_type|
              command_type = command[supported_command_type]
              next unless command_type

              component_name = command_type.fetch(:component)
              next unless component_name.downcase.start_with?(RESTRICTED_PREFIX)

              return err(
                format(
                  _("Component name '%{component}' for command id '%{command}' must not start with '%{prefix}'"),
                  component: component_name,
                  command: command_id,
                  prefix: RESTRICTED_PREFIX
                )
              )
            end
          end

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_events(context)
          context => { processed_devfile: Hash => processed_devfile }

          processed_devfile.fetch(:events).each do |event_type, event_type_events|
            # Ensure no event type other than "preStart" are allowed

            unless SUPPORTED_EVENTS.include?(event_type)
              return err(format(_("Event type '%{type}' is not yet supported"), type: event_type))
            end

            # Ensure no event starts with restricted_prefix
            event_type_events.each do |event|
              next unless event.downcase.start_with?(RESTRICTED_PREFIX)

              return err(
                format(
                  _("Event '%{event}' of type '%{event_type}' must not start with '%{prefix}'"),
                  event: event,
                  event_type: event_type,
                  prefix: RESTRICTED_PREFIX
                )
              )
            end
          end

          Gitlab::Fp::Result.ok(context)
        end

        # @param [Hash] context
        # @return [Gitlab::Fp::Result]
        def self.validate_variables(context)
          context => { processed_devfile: Hash => processed_devfile }

          restricted_prefix_underscore = RESTRICTED_PREFIX.tr("-", "_")

          # Ensure no variable name starts with restricted_prefix
          processed_devfile.fetch(:variables).each_key do |variable|
            [RESTRICTED_PREFIX, restricted_prefix_underscore].each do |prefix|
              next unless variable.downcase.start_with?(prefix)

              return err( # rubocop:disable Cop/AvoidReturnFromBlocks -- We want to use a return here - it works fine, and the alternative is unnecessarily complex.
                format(
                  _("Variable name '%{variable}' must not start with '%{prefix}'"),
                  variable: variable,
                  prefix: prefix
                )
              )
            end
          end

          Gitlab::Fp::Result.ok(context)
        end

        # @param [String] details
        # @return [Gitlab::Fp::Result]
        def self.err(details)
          Gitlab::Fp::Result.err(WorkspaceCreatePostFlattenDevfileValidationFailed.new({ details: details }))
        end
        private_class_method :validate_projects, :validate_components, :validate_containers,
          :validate_endpoints, :validate_commands, :validate_events,
          :validate_variables, :err, :validate_root_attributes
      end
    end
  end
end
