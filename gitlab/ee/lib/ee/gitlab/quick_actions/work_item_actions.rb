# frozen_string_literal: true

module EE
  module Gitlab
    module QuickActions
      module WorkItemActions
        extend ActiveSupport::Concern
        extend ::Gitlab::Utils::Override
        include ::Gitlab::QuickActions::Dsl

        included do
          desc { _('Configure checkin reminder frequency') }
          explanation do |frequency|
            format(_("Sets checkin reminder frequency to %{frequency}."), frequency: frequency)
          end
          params "<#{::WorkItems::Progress.reminder_frequencies.keys.join(' | ')}"
          types WorkItem
          condition do
            ::Feature.enabled?(:okr_checkin_reminders,
              project) && quick_action_target.work_item_type.objective? && current_user.can?(:admin_issue,
                project)
          end
          parse_params do |frequency|
            find_frequency(frequency)
          end
          command :checkin_reminder do |frequency|
            if frequency
              @execution_message[:checkin_reminder] = _('Checkin reminder has been enabled.')
              @updates[:progress] = update_progress(frequency)
            end
          end
        end

        private

        override :promote_to_map
        def promote_to_map
          super.merge(key_result: ['Objective'], issue: super['issue'].push('Epic'))
        end

        override :apply_type_commands
        def apply_type_commands(new_type, command)
          return super unless command == :promote_to && new_type.epic?

          begin
            Epics::IssuePromoteService
              .new(container: quick_action_target.container, current_user: current_user)
              .execute(quick_action_target)

            success_msg[command]
          rescue StandardError
            error_msg(:not_found, action: 'promote')
          end
        end

        override :validate_promote_to
        def validate_promote_to(type)
          return super unless type&.epic?

          container = quick_action_target.container
          issue_group = container.is_a?(Group) ? container : container.group

          return if quick_action_target.can_be_promoted_to_epic?(current_user, issue_group)

          error_msg(:not_found, action: 'promote')
        end

        override :type_change_allowed?
        def type_change_allowed?
          true unless quick_action_target.work_item_type.epic?
        end

        def find_frequency(frequency)
          return unless frequency

          frequency_param = frequency.downcase.underscore
          reminder_frequencies = ::WorkItems::Progress.reminder_frequencies.keys

          reminder_frequencies.include?(frequency_param) && frequency_param
        end

        def update_progress(frequency)
          progress = quick_action_target.progress || quick_action_target.build_progress
          progress.reminder_frequency = find_frequency(frequency)

          ::SystemNoteService.change_checkin_reminder_note(quick_action_target, current_user)

          progress
        end

        override :extract_work_items
        def extract_work_items(params)
          return if params.nil?

          issues_and_work_items = super
          epics = extract_references(params, :epic)

          epics.map(&:sync_object) + issues_and_work_items
        end
      end
    end
  end
end
