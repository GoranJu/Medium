# frozen_string_literal: true

namespace :gitlab do
  namespace :work_items do
    namespace :epics do
      desc "GitLab | Enables work item epics"
      task enable: :environment do
        puts "\nThis script will check for inconsistencies between the `epics` and `work_items` tables " \
          "and might take a few minutes to complete."
        puts "\n\nWhen there are no inconsistencies, work item epics will be enabled."
        puts "When inconsistencies are found, work item epics will not be enabled and " \
          "you'll get more information in the error log.\n"
        puts "\n\nWhen work item epics are generally available and enabled by default, " \
          "these inconsistencies have been resolved.\n\n"

        progress_bar ||= ProgressBar.create(
          title: 'Verifying epics',
          total: Gitlab::Database::PgClass.for_table('epics')&.cardinality_estimate,
          format: '%t: |%B| %c/%C'
        )

        verifications = verifier.verify do |progress|
          new_progress = progress[:valid] + progress[:mismatched]
          progress_bar.progress = new_progress if progress_bar.progress + new_progress <= progress_bar.total
        end

        progress_bar.finish

        if verifications[:mismatched] > 0
          puts Rainbow("\n#{verifications[:mismatched]} out of #{verifications[:valid] + verifications[:mismatched]} " \
            "epics have attributes that are out of sync. We are not able to enable work item epics right now.").red
          puts "\nPlease wait for work item epics to be generally available. " \
            "You can find a detailed breakdown of the relevant syncing issues in the " \
            "#{Rainbow('epic_work_item_sync.log').green} file.\n\n"
        else
          puts Rainbow("Verified #{verifications[:valid]} epics.").green
          Feature.enable(:work_item_epics)
          puts Rainbow("Successfully enabled work item epics").green
        end
      end

      task disable: :environment do
        Feature.disable(:work_item_epics)

        puts Rainbow("Successfully disabled work item epics.").green
      end

      private

      def filtered_attributes
        %w[closed_at closed_by_id confidential description iid state_id title epic_issue related_links parent_id]
      end

      def verifier
        ::Gitlab::EpicWorkItemSync::BulkVerification.new(filter_attributes: filtered_attributes)
      end
    end
  end
end
