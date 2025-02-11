# frozen_string_literal: true

module EE
  module NotesFinder
    extend ActiveSupport::Concern
    extend ::Gitlab::Utils::Override

    override :noteables_for_type
    def noteables_for_type(noteable_type)
      case noteable_type
      when 'epic'
        return EpicsFinder.new(@current_user, group_id: @params[:group_id]) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      when 'vulnerability'
        return ::Security::VulnerabilityReadsFinder.new(@project) # rubocop:disable Gitlab/ModuleWithInstanceVariables
      end

      super
    end

    override :notes_on_target
    def notes_on_target
      if target.respond_to?(:related_notes)
        target.related_notes
      elsif target.is_a?(::Vulnerabilities::Read)
        target.vulnerability.notes
      else
        target.notes
      end
    end
  end
end
