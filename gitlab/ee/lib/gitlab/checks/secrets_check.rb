# frozen_string_literal: true

module Gitlab
  module Checks
    class SecretsCheck < ::Gitlab::Checks::BaseBulkChecker
      include ::Gitlab::InternalEventsTracking
      include ::Gitlab::Utils::StrongMemoize
      include ::Gitlab::Loggable

      ERROR_MESSAGES = {
        failed_to_scan_regex_error: "\n    - Failed to scan blob(id: %{payload_id}) due to regex error.",
        blob_timed_out_error: "\n    - Scanning blob(id: %{payload_id}) timed out.",
        scan_timeout_error: 'Secret detection scan timed out.',
        scan_initialization_error: 'Secret detection scan failed to initialize. %{error_msg}',
        invalid_input_error: 'Secret detection scan failed due to invalid input.',
        invalid_scan_status_code_error: 'Invalid secret detection scan status, check passed.',
        too_many_tree_entries_error: 'Too many tree entries exist for commit(sha: %{sha}).'
      }.freeze

      LOG_MESSAGES = {
        secrets_check: 'Detecting secrets...',
        secrets_not_found: 'Secret detection scan completed with no findings.',
        skip_secret_detection: "\n\nTo skip secret push protection, add the following Git push option " \
                               "to your push command: `-o secret_push_protection.skip_all`",
        found_secrets: "\nPUSH BLOCKED: Secrets detected in code changes",
        found_secrets_post_message: "\n\nTo push your changes you must remove the identified secrets.",
        found_secrets_docs_link: "\nFor guidance, see %{path}",
        found_secrets_with_errors: 'Secret detection scan completed with one or more findings ' \
                                   'but some errors occured during the scan.',
        finding_message_occurrence_header: "\n\nSecret push protection " \
                                           "found the following secrets in commit: %{sha}",
        finding_message_occurrence_path: "\n-- %{path}:",
        finding_message_occurrence_line: "%{line_number} | %{description}",
        finding_message: "\n\nSecret leaked in blob: %{payload_id}" \
                         "\n  -- line:%{line_number} | %{description}",
        found_secrets_footer: "\n--------------------------------------------------\n\n",
        invalid_encoding: "Could not convert data to UTF-8 from %{encoding}",
        sds_disabled: "SDS is disabled: FF: %{sds_ff_enabled}, SaaS: %{saas_feature_enabled}, " \
                      "Non-Dedicated: %{is_not_dedicated}",
        invalid_log_level: "Unknown log level %{log_level} for message: %{message}"
      }.freeze

      PAYLOAD_BYTES_LIMIT = 1.megabyte # https://handbook.gitlab.com/handbook/engineering/architecture/design-documents/secret_detection/#target-types
      SPECIAL_COMMIT_FLAG = /\[skip secret push protection\]/i
      DOCUMENTATION_PATH = 'user/application_security/secret_detection/secret_push_protection/_index.html'
      DOCUMENTATION_PATH_ANCHOR = 'resolve-a-blocked-push'
      EXCLUSION_TYPE_MAP = {
        rule: ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_RULE,
        path: ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_PATH,
        raw_value: ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_RAW_VALUE,
        unknown: ::Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_UNSPECIFIED
      }.freeze

      # HUNK_HEADER_REGEX matches a line starting with @@, followed by - and digits (starting line number
      # and range in the original file, comma and more digits optional), then + and digits (starting line number
      # and range in the new file, comma and more digits optional), ending with @@.
      # Allows for optional section headings after the final @@.
      HUNK_HEADER_REGEX = /\A@@ -\d+(,\d+)? \+(\d+)(,\d+)? @@.*\Z/

      # Maximum depth any path exclusion can have.
      MAX_PATH_EXCLUSIONS_DEPTH = 20

      # rubocop:disable Metrics/AbcSize -- This will be refactored in this epic (https://gitlab.com/groups/gitlab-org/-/epics/16376)
      def validate!
        # Return early and do not perform the check:
        #   1. unless license is ultimate
        #   2. unless application setting is enabled
        #   3. unless project setting is enabled
        #   4. if it is a delete branch/tag operation, as it would require scanning the entire revision history
        #   5. if options are passed for us to skip the check

        return unless project.licensed_feature_available?(:secret_push_protection)

        return unless run_secret_push_protection?

        return if includes_full_revision_history?

        # Skip if any commit has the special bypass flag `[skip secret push protection]`
        if skip_secret_detection_commit_message?
          log_audit_event(_("commit message")) # Keeping this a string and not constant so I18N picks it up
          track_spp_skipped("commit message")
          return
        end

        if skip_secret_detection_push_option?
          log_audit_event(_("push option")) # Keeping this a string and not constant so I18N picks it up
          track_spp_skipped("push option")
          return
        end

        if use_secret_detection_service?
          sds_host = ::Gitlab::CurrentSettings.current_application_settings.secret_detection_service_url
          @sds_auth_token = ::Gitlab::CurrentSettings.current_application_settings.secret_detection_service_auth_token

          unless sds_host.blank?
            begin
              @sds_client =
                ::Gitlab::SecretDetection::GRPC::Client.new(
                  sds_host,
                  secure: !sds_auth_token.blank?,
                  logger: secret_detection_logger
                )
            rescue StandardError => e # Currently we want to catch and simply log errors
              @sds_client = nil
              ::Gitlab::ErrorTracking.track_exception(e)
            end
          end
        end

        thread = nil

        logger.log_timed(LOG_MESSAGES[:secrets_check]) do
          # Ensure consistency between different payload types (e.g., git diffs and full files) for scanning.
          payloads = standardize_payloads

          if use_secret_detection_service?
            thread = Thread.new do
              # This is to help identify the thread in case of a crash
              Thread.current.name = "secrets_check"

              # All the code run in the thread handles exceptions so we can leave these off
              Thread.current.abort_on_exception = false
              Thread.current.report_on_exception = false

              send_request_to_sds(payloads, exclusions: active_exclusions)
            end
          end

          # Pass payloads to gem for scanning.
          response = ::Gitlab::SecretDetection::Core::Scanner
            .new(rules: ruleset, logger: secret_detection_logger)
            .secrets_scan(
              payloads,
              timeout: logger.time_left,
              exclusions: active_exclusions
            )

          # Log audit events for exlusions that were applied.
          log_applied_exclusions_audit_events(response.applied_exclusions)

          # Handle the response depending on the status returned.
          response = format_response(response)

          # Wait for the thread to complete up until we time out, returns `nil` on timeout
          thread&.join(logger.time_left)

          response
        # TODO: Perhaps have a separate message for each and better logging?
        rescue ::Gitlab::SecretDetection::Core::Scanner::RulesetParseError,
          ::Gitlab::SecretDetection::Core::Scanner::RulesetCompilationError => e

          message = format(ERROR_MESSAGES[:scan_initialization_error], { error_msg: e.message })
          secret_detection_logger.error(build_structured_payload(message:))
        ensure
          # clean up the thread
          thread&.exit
        end
      end
      # rubocop:enable Metrics/AbcSize

      private

      attr_reader :sds_client, :sds_auth_token

      ##############################
      # Helpers

      def ruleset
        ::Gitlab::SecretDetection::Core::Ruleset.new(
          logger: secret_detection_logger
        ).rules
      end

      strong_memoize_attr :ruleset

      ##############################
      # Project Eligibility Checks

      def run_secret_push_protection?
        ::Gitlab::CurrentSettings.current_application_settings.secret_push_protection_available &&
          project.security_setting&.secret_push_protection_enabled
      end

      def use_secret_detection_service?
        return @should_use_sds unless @should_use_sds.nil?

        sds_ff_enabled = Feature.enabled?(:use_secret_detection_service, project)
        saas_feature_enabled = ::Gitlab::Saas.feature_available?(:secret_detection_service)
        is_not_dedicated = !::Gitlab::CurrentSettings.gitlab_dedicated_instance

        @should_use_sds = sds_ff_enabled && saas_feature_enabled && is_not_dedicated

        unless @should_use_sds
          msg = format(LOG_MESSAGES[:sds_disabled], { sds_ff_enabled:, saas_feature_enabled:, is_not_dedicated: })
          secret_detection_logger.info(build_structured_payload(message: msg))
        end

        @should_use_sds
      end

      ###############
      # Scan Checks

      def http_or_ssh_protocol?
        %w[http ssh].include?(changes_access.protocol)
      end

      def use_diff_scan?
        Feature.enabled?(:spp_scan_diffs, project) && http_or_ssh_protocol?
      end

      def includes_full_revision_history?
        ::Gitlab::Git.blank_ref?(changes_access.changes.first[:newrev])
      end

      def skip_secret_detection_commit_message?
        changes_access.commits.any? { |commit| commit.safe_message =~ SPECIAL_COMMIT_FLAG }
      end

      def skip_secret_detection_push_option?
        changes_access.push_options&.get(:secret_push_protection, :skip_all)
      end

      ############################
      # Audits and Event Logging

      def secret_detection_logger
        @secret_detection_logger ||= ::Gitlab::SecretDetectionLogger.build
      end

      def generate_target_details
        changes = changes_access.changes
        old_rev = changes.first&.dig(:oldrev)
        new_rev = changes.last&.dig(:newrev)

        return project.name if old_rev.nil? || new_rev.nil?

        ::Gitlab::Utils.append_path(
          ::Gitlab::Routing.url_helpers.root_url,
          ::Gitlab::Routing.url_helpers.project_compare_path(project, from: old_rev, to: new_rev)
        )
      end

      def log_audit_event(skip_method)
        branch_name = changes_access.single_change_accesses.first.branch_name
        message = "#{_('Secret push protection skipped via')} #{skip_method} on branch #{branch_name}"
        audit_context = {
          name: 'skip_secret_push_protection',
          author: changes_access.user_access.user,
          target: project,
          scope: project,
          message: message,
          target_details: generate_target_details
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def log_applied_exclusions_audit_events(applied_exclusions)
        # Calling ::Gitlab::Audit::Auditor.audit directly in `gitlab-secret_detection` gem is not
        # feasible so instead of doing that, we loop through exclusions that have been applied during
        # scanning of either `rule` or `raw_value` type. For `path` exclusions, we create the audit events
        # when applied while formatting the response.
        applied_exclusions.each do |exclusion|
          project_security_exclusion = get_project_security_exclusion_from_sds_exclusion(exclusion)
          log_exclusion_audit_event(project_security_exclusion) unless project_security_exclusion.nil?
        end
      end

      def get_project_security_exclusion_from_sds_exclusion(exclusion)
        return exclusion if exclusion.is_a?(::Security::ProjectSecurityExclusion)

        # TODO When we implement 2-way SDS communication, we should add the type to this lookup
        project.security_exclusions.where(value: exclusion.value).first # rubocop:disable CodeReuse/ActiveRecord -- Need to be able to link GRPC::Exclusion to ProjectSecurityExclusion
      end

      def log_exclusion_audit_event(exclusion)
        audit_context = {
          name: 'project_security_exclusion_applied',
          author: changes_access.user_access.user,
          target: exclusion,
          scope: project,
          message: "An exclusion of type (#{exclusion.type}) with value (#{exclusion.value}) was " \
                   "applied in Secret push protection"
        }

        ::Gitlab::Audit::Auditor.audit(audit_context)
      end

      def track_spp_skipped(skip_method)
        track_internal_event(
          'skip_secret_push_protection',
          user: changes_access.user_access.user,
          project: project,
          namespace: project.namespace,
          additional_properties: {
            label: skip_method
          }
        )
      end

      def track_secret_found(secret_type)
        track_internal_event(
          'detect_secret_type_on_push',
          user: changes_access.user_access.user,
          project: changes_access.project,
          namespace: changes_access.project.namespace,
          additional_properties: {
            label: secret_type
          }
        )
      end

      #######################
      # Load Payloads

      # The `standardize_payloads` method gets payloads containing either git diffs or entire file contents
      # and converts them into a standardized format. Each payload is processed to include its `id`, `data`,
      # and `offset` (used to calculate the line number that a secret is on).
      # This ensures consistency between different payload types (e.g., git diffs and full files) for scanning.
      # For a more thorough explanation of the diff parsing logic, see the comment above the `parse_diffs` method.

      def standardize_payloads
        if use_diff_scan?
          payloads = get_diffs

          payloads = payloads.flat_map do |payload|
            p_ary = parse_diffs(payload)
            build_payloads(p_ary)
          end

          payloads.compact.empty? ? nil : payloads
        else
          payloads = ::Gitlab::Checks::ChangedBlobs.new(
            project, revisions, bytes_limit: PAYLOAD_BYTES_LIMIT + 1
          ).execute(timeout: logger.time_left)

          # Filter out larger than PAYLOAD_BYTES_LIMIT blobs and binary blobs.
          payloads.reject! { |payload| payload.size > PAYLOAD_BYTES_LIMIT || payload.binary }

          payloads.map do |payload|
            build_payload(
              {
                id: payload.id,
                data: payload.data,
                offset: 1
              }
            )
          end
        end
      end

      def get_diffs
        diffs = []
        # Get new commits
        commits = project.repository.new_commits(revisions)

        # Get changed paths
        paths = project.repository.find_changed_paths(commits, merge_commit_diff_mode: :all_parents)

        # Reject diff blob objects from paths that are excluded
        # -- TODO: pass changed paths with diff blob objects and move this exclusion process into the gem.
        paths.reject! { |changed_path| matches_excluded_path?(changed_path.path) }

        # Make multiple DiffBlobsRequests with smaller batch sizes to prevent timeout when generating diffs
        paths.each_slice(50) do |paths_slice|
          blob_pair_ids = paths_slice.map do |path|
            Gitaly::DiffBlobsRequest::BlobPair.new(
              left_blob: path.old_blob_id,
              right_blob: path.new_blob_id
            )
          end

          diff_slice = project.repository.diff_blobs(blob_pair_ids, patch_bytes_limit: PAYLOAD_BYTES_LIMIT).to_a

          # Filter out diffs above 1 Megabyte and binary diffs
          filtered_diffs = diff_slice.reject { |diff| diff.over_patch_bytes_limit || diff.binary }

          diffs.concat(filtered_diffs)
        rescue GRPC::InvalidArgument => e
          ::Gitlab::ErrorTracking.track_exception(e)
        end
        diffs
      end

      # The parse_diffs method processes a diff patch to extract and group all added lines
      #   based on their position in the file.
      #
      # If the line starts with "@@", it is the hunk header, used to calculate the line offset.
      # If the line starts with "+", it is newly added in this commit,
      #   and we append the line content to a buffer and track the current line offset.
      #   If consecutive lines are added, they are grouped together in the same string with a shared offset value.
      # If the line starts with " ", it is a context line,
      #   just increment the offset counter to maintain accurate line numbers.
      # Lines starting with "-" (removed lines) and "\\" (end of diff) are ignored.
      #
      # Once the entire diff is parsed, the method returns an array of hashes containing:
      # - `id`: The id of the blob that the diff corresponds to (`diff.right_blob_id`).
      # - `data`: A string representing the concatenated added lines.
      # - `offset`: An integer indicating the line number in the file where this group of added lines starts.
      #
      # So for this example diff:
      #
      # @@ -0,0 +1,2 @@
      # +new line
      # +another added line in the same section
      # @@ -7,1 +8,2 @@
      #  unchanged line here
      # +another new line
      #
      # We would process it into:
      #
      # [{
      #    id: "123abc",
      #    data: "new line\nanother added line in the same section\n",
      #    offset: 1
      #  },
      #  {
      #    id: "123abc",
      #    data: "another new line\n",
      #    offset: 8
      #  }]

      def parse_diffs(diff)
        hunk_headers = diff.patch.each_line.select { |line| line.start_with?("@@") }
        invalid_hunk = hunk_headers.find { |header| !header.match(HUNK_HEADER_REGEX) }

        if invalid_hunk
          secret_detection_logger.error(
            build_structured_payload(
              message:
              "Could not process hunk header: #{invalid_hunk.strip}, skipped parsing diff: #{diff.right_blob_id}"
            )
          )
          return []
        end

        diff_parsed_lines = []
        current_line_number = 0
        added_content = ''
        offset = nil

        diff.patch.each_line do |line|
          # Parse hunk header for start line
          if line.start_with?("@@")
            hunk_info = line.match(HUNK_HEADER_REGEX)
            start_line = hunk_info[2].to_i
            current_line_number = start_line - 1

            # Push previous payload if not empty
            unless added_content.empty?
              diff_parsed_lines << { id: diff.right_blob_id, data: added_content.delete_suffix("\n"), offset: offset }
              added_content = ''
              offset = nil
            end

          # Line added in this commit
          elsif line.start_with?('+')
            added_content += line[1..] # Add the line content without '+'
            current_line_number += 1
            offset ||= current_line_number

          # Context line
          elsif line.start_with?(' ')
            unless added_content.empty?
              diff_parsed_lines << { id: diff.right_blob_id, data: added_content.delete_suffix("\n"), offset: offset }
              added_content = ''
              offset = nil
            end

            current_line_number += 1
          elsif line.start_with?('-', '\\')
            # Line removed in this commit or no newline marker, do not increment line number
            next
          end
        end

        # Push the final payload if not empty
        unless added_content.empty?
          diff_parsed_lines << {
            id: diff.right_blob_id, data: added_content.delete_suffix("\n"), offset: offset
          }
        end

        diff_parsed_lines
      end

      #######################
      # Format Scan Results

      def commits
        @commit ||= changes_access.commits.map(&:valid_full_sha)
      end

      def revisions
        @revisions ||= changes_access
                        .changes
                        .pluck(:newrev) # rubocop:disable CodeReuse/ActiveRecord -- Array#pluck
                        .reject { |revision| ::Gitlab::Git.blank_ref?(revision) }
                        .compact
      end

      def format_response(response)
        # Try to retrieve file path and commit sha for the diffs found.
        if [
          ::Gitlab::SecretDetection::Core::Status::FOUND,
          ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS
        ].include?(response.status)
          results = transform_findings(response)

          # If there is no findings in `response.results`, that means all findings
          # were excluded in `transform_findings`, so we set status to no secrets found.
          response.status = ::Gitlab::SecretDetection::Status::NOT_FOUND if response.results.empty?
        end

        case response.status
        when ::Gitlab::SecretDetection::Core::Status::NOT_FOUND
          # No secrets found, we log and skip the check.
          secret_detection_logger.info(build_structured_payload(message: LOG_MESSAGES[:secrets_not_found]))
        when ::Gitlab::SecretDetection::Core::Status::FOUND
          # One or more secrets found, generate message with findings and fail check.
          message = build_secrets_found_message(results)

          secret_detection_logger.info(
            build_structured_payload(message: LOG_MESSAGES[:found_secrets])
          )

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Core::Status::FOUND_WITH_ERRORS
          # One or more secrets found, but with scan errors, so we
          # generate a message with findings and errors, and fail the check.
          message = build_secrets_found_message(results, with_errors: true)

          secret_detection_logger.info(
            build_structured_payload(message: LOG_MESSAGES[:found_secrets_with_errors])
          )

          raise ::Gitlab::GitAccess::ForbiddenError, message
        when ::Gitlab::SecretDetection::Core::Status::SCAN_TIMEOUT
          # Entire scan timed out, we log and skip the check for now.
          secret_detection_logger.error(
            build_structured_payload(message: ERROR_MESSAGES[:scan_timeout_error])
          )
        when ::Gitlab::SecretDetection::Core::Status::INPUT_ERROR
          # Scan failed due to invalid input. We skip the check because of an input error
          # which could be due to not having anything to scan.
          secret_detection_logger.error(
            build_structured_payload(message: ERROR_MESSAGES[:invalid_input_error])
          )
        else
          # Invalid status returned by the scanning service/gem, we don't
          # know how to handle that, so nothing happens and we skip the check.
          secret_detection_logger.error(
            build_structured_payload(message: ERROR_MESSAGES[:invalid_scan_status_code_error])
          )
        end
      end

      def build_secrets_found_message(results, with_errors: false)
        message = with_errors ? LOG_MESSAGES[:found_secrets_with_errors] : LOG_MESSAGES[:found_secrets]

        results[:commits].each do |sha, paths|
          message += format(LOG_MESSAGES[:finding_message_occurrence_header], { sha: sha })

          paths.each do |path, findings|
            findings.each do |finding|
              message += format(LOG_MESSAGES[:finding_message_occurrence_path], { path: path })
              message += build_finding_message(finding, :commit)
            end
          end
        end

        results[:blobs].compact.each do |_, findings|
          findings.each do |finding|
            message += build_finding_message(finding, :blob)
          end
        end

        message += LOG_MESSAGES[:found_secrets_post_message]
        message += format(
          LOG_MESSAGES[:found_secrets_docs_link],
          {
            path: Rails.application.routes.url_helpers.help_page_url(
              DOCUMENTATION_PATH,
              anchor: DOCUMENTATION_PATH_ANCHOR
            )
          }
        )

        message += LOG_MESSAGES[:skip_secret_detection]
        message += LOG_MESSAGES[:found_secrets_footer]
        message
      end

      def build_finding_message(finding, type)
        case finding.status
        when ::Gitlab::SecretDetection::Core::Status::FOUND
          track_secret_found(finding.description)

          case type
          when :commit
            build_commit_finding_message(finding)
          when :blob
            build_blob_finding_message(finding)
          end
        when ::Gitlab::SecretDetection::Core::Status::SCAN_ERROR
          format(ERROR_MESSAGES[:failed_to_scan_regex_error], finding.to_h)
        when ::Gitlab::SecretDetection::Core::Status::PAYLOAD_TIMEOUT
          format(ERROR_MESSAGES[:blob_timed_out_error], finding.to_h)
        end
      end

      def build_commit_finding_message(finding)
        format(
          LOG_MESSAGES[:finding_message_occurrence_line],
          {
            line_number: finding.line_number,
            description: finding.description
          }
        )
      end

      def build_blob_finding_message(finding)
        format(LOG_MESSAGES[:finding_message], finding.to_h)
      end

      # rubocop:disable Metrics/CyclomaticComplexity -- Not easy to move complexity away into other methods, entire method will be refactored shortly.
      def transform_findings(response)
        # Let's group the findings by the blob id.
        findings_by_blobs = response.results.group_by(&:payload_id)

        # We create an empty hash for the structure we'll create later as we pull out tree entries.
        findings_by_commits = {}

        # Let's create a set to store ids of blobs found in tree entries.
        blobs_found_with_tree_entries = Set.new

        # Scanning had found secrets, let's try to look up their file path and commit id. This can be done
        # by using `GetTreeEntries()` RPC, and cross examining blobs with ones where secrets where found.
        commits.each do |revision|
          # We could try to handle pagination, but it is likely to timeout way earlier given the
          # huge default limit (100000) of entries, so we log an error if we get too many results.
          entries, cursor = ::Gitlab::Git::Tree.tree_entries(
            repository: project.repository,
            sha: revision,
            recursive: true,
            rescue_not_found: false
          )

          # TODO: Handle pagination in the upcoming iterations
          # We don't raise because we could still provide a hint to the user
          # about the detected secrets even without a commit sha/file path information.
          unless cursor.next_cursor.empty?
            secret_detection_logger.error(
              build_structured_payload(
                message: format(ERROR_MESSAGES[:too_many_tree_entries_error], { sha: revision })
              )
            )
          end

          # Let's grab the `commit_id` and the `path` for that entry, we use the blob id as key.
          entries.each do |entry|
            # Skip any entry that isn't a blob.
            next if entry.type != :blob

            # Skip if the blob doesn't have any findings.
            next unless findings_by_blobs[entry.id].present?

            # Skip a tree entry if it's excluded from scanning by the user based on its file
            # path. We unfortunately have to do this after scanning is done because we only get
            # file paths when calling `GetTreeEntries()` RPC and not earlier. When diff scanning
            # is available, we will likely be able move this check to the gem/secret detection service
            # since paths will be available pre-scanning.
            if matches_excluded_path?(entry.path)
              response.results.delete_if { |finding| finding.payload_id == entry.id }

              findings_by_blobs.delete(entry.id)

              next
            end

            new_entry = findings_by_blobs[entry.id].each_with_object({}) do |finding, hash|
              hash[entry.commit_id] ||= {}
              hash[entry.commit_id][entry.path] ||= []
              hash[entry.commit_id][entry.path] << finding
            end

            # Put findings with tree entries inside `findings_by_commits` hash.
            findings_by_commits.merge!(new_entry) do |_commit_sha, existing_findings, new_findings|
              existing_findings.merge!(new_findings)
            end

            # Mark as found with tree entry already.
            blobs_found_with_tree_entries << entry.id
          end
        end

        # Remove blobs that has already been found in a tree entry.
        findings_by_blobs.delete_if { |payload_id, _| blobs_found_with_tree_entries.include?(payload_id) }

        # Return the findings as a hash sorted by commits and blobs (minus ones already found).
        {
          commits: findings_by_commits,
          blobs: findings_by_blobs
        }
      end
      # rubocop:enable Metrics/CyclomaticComplexity

      ##############
      # Exclusions

      def active_exclusions
        @active_exclusions ||= project
          .security_exclusions
          .by_scanner(:secret_push_protection)
          .active
          .select(:type, :value)
          .group_by { |exclusion| exclusion.type.to_sym }
      end

      def matches_excluded_path?(path)
        # Skip paths that are too deep.
        return false if path.count('/') > MAX_PATH_EXCLUSIONS_DEPTH

        # Check only the maximum amount of path exclusions allowed (i.e. 10 path exclusions).
        active_exclusions[:path]
          &.first(::Security::ProjectSecurityExclusion::MAX_PATH_EXCLUSIONS_PER_PROJECT)
          &.any? do |exclusion|
          matches = File.fnmatch?(
            exclusion.value,
            path,
            File::FNM_DOTMATCH | File::FNM_EXTGLOB | File::FNM_PATHNAME
          )

          log_exclusion_audit_event(exclusion) if matches

          matches
        end
      end

      ##############
      # GRPC Client Helpers

      def send_request_to_sds(payloads, exclusions: {})
        return if sds_client.nil?

        request = build_sds_request(payloads, exclusions: exclusions)

        # ignore the response for now
        _ = sds_client.run_scan(request: request, auth_token: sds_auth_token)
      rescue StandardError => e # Currently we want to catch and simply log errors
        ::Gitlab::ErrorTracking.track_exception(e)
      end

      # Expects an array of either Hashes or ScanRequest::Payloads
      def build_payloads(data)
        data.inject([]) do |payloads, datum|
          payloads << build_payload(datum)
        end.compact
      end

      # Expect `payload` is a hash or GRPC::ScanRequest::Payload object
      def build_payload(datum)
        return datum if datum.is_a?(::Gitlab::SecretDetection::GRPC::ScanRequest::Payload)

        original_encoding = datum[:data].encoding

        unless original_encoding == Encoding::UTF_8
          datum[:data] = datum[:data].dup.force_encoding('UTF-8') # Incident 19090 (https://gitlab.com/gitlab-com/gl-infra/production/-/issues/19090)
        end

        unless datum[:data].valid_encoding?
          log_msg = format(LOG_MESSAGES[:invalid_encoding], { encoding: original_encoding })
          secret_detection_logger.warn(
            build_structured_payload(message: log_msg)
          )
          return
        end

        ::Gitlab::SecretDetection::GRPC::ScanRequest::Payload.new(
          id: datum[:id],
          data: datum[:data], # Incident 19090 (https://gitlab.com/gitlab-com/gl-infra/production/-/issues/19090)
          offset: datum.fetch(:offset, nil)
        )
      end

      # Build the list of gRPC Exclusion objects
      def build_exclusions(exclusions: {})
        exclusion_ary = []

        # exclusions are a hash of {string, array} pairs where the keys
        # are exclusion types like raw_value or path
        exclusions.each_key do |key|
          exclusions[key].inject(exclusion_ary) do |array, exclusion|
            type = EXCLUSION_TYPE_MAP.fetch(exclusion.type.to_sym, EXCLUSION_TYPE_MAP[:unknown])

            array << ::Gitlab::SecretDetection::GRPC::Exclusion.new(
              exclusion_type: type,
              value: exclusion.value
            )
          end
        end

        exclusion_ary
      end

      # Puts the entire gRPC request object together
      def build_sds_request(payloads, exclusions: {}, tags: [])
        exclusion_ary = build_exclusions(exclusions:)

        ::Gitlab::SecretDetection::GRPC::ScanRequest.new(
          payloads: payloads,
          exclusions: exclusion_ary,
          tags: tags
        )
      end
    end
  end
end
