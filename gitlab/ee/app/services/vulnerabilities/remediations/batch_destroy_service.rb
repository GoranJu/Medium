# frozen_string_literal: true

module Vulnerabilities
  module Remediations
    class BatchDestroyService
      include BaseServiceUtility

      def initialize(remediations:)
        @remediations = remediations
      end

      def execute
        return success_response if remediations.blank?
        raise argument_error unless remediations.is_a?(ActiveRecord::Relation)

        remediations
          .tap { |remediations| destroy_uploads!(remediations) }
          .then(&:delete_all)
          .then { |deleted_count| success_response(deleted_count) }
      end

      private

      attr_reader :remediations

      def argument_error
        ArgumentError.new('remediations must be of type ActiveRecord::Relation')
      end

      def destroy_uploads!(remediations)
        # rubocop: disable CodeReuse/ActiveRecord -- couldn't find a Finder to use
        Upload.where(
          model_type: Vulnerabilities::Remediation,
          model_id: remediations.pluck_primary_key,
          uploader: AttachmentUploader
        ).then { |uploads| [uploads, uploads.begin_fast_destroy] }
          .tap { |uploads, _| uploads.delete_all }
          .tap { |_, files| Upload.finalize_fast_destroy(files) }
        # rubocop: enable CodeReuse/ActiveRecord
      end

      def success_response(deleted_count = 0)
        ServiceResponse.success(payload: { rows_deleted: deleted_count })
      end
    end
  end
end
