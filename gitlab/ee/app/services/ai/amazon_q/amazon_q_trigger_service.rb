# frozen_string_literal: true

module Ai
  module AmazonQ
    class AmazonQTriggerService < BaseService
      include ::Gitlab::Utils::StrongMemoize

      CloudConnectorTokenError = Class.new(StandardError)
      ServiceAccountError = Class.new(StandardError)
      CompositeIdentityEnforcedError = Class.new(StandardError)
      MissingPrerequisiteError = Class.new(StandardError)

      REVIEW_FINDING_KEYWORDS = ["We detected", "We recommend", "Severity:"].freeze

      def initialize(user:, command:, source:, note: nil, discussion_id: nil, input: nil)
        @user = user
        @command = command
        @input = input
        @source = source
        @note = note
        @discussion_id = discussion_id
      end

      attr_reader :user, :command, :source, :note, :discussion_id, :input

      def execute
        validate_cloud_connector_token!
        validate_service_account!
        validate_source!
        validate_command!
        validate_code_position! if command == 'test'

        add_service_account_to_project

        SystemNoteService.amazon_q_called(source, user, command)
        create_note_if_needed

        response = make_ai_gateway_request
        handle_response(response)
        response
      rescue StandardError => e
        Gitlab::ErrorTracking.log_exception(e)
        handle_note_error(e.message)
      end

      private

      def make_ai_gateway_request
        client = Gitlab::Llm::QAi::Client.new(user)

        client.create_event(
          payload: payload,
          auth_grant: create_auth_grant_new,
          role_arn: ai_settings.amazon_q_role_arn
        )
      end

      def service_name
        :amazon_q_integration
      end

      def cloud_connector_token
        ::CloudConnector::AvailableServices.find_by_name(service_name).access_token
      end
      strong_memoize_attr :cloud_connector_token

      def handle_response(response)
        return if response.success?

        update_failure_note
      end

      def payload
        ::Ai::AmazonQ::RequestPayload.new(
          command: command,
          source: source,
          note: note,
          service_account_notes: service_account_notes,
          discussion_id: discussion_id,
          input: input,
          line_position_for_comment: line_position_for_comment
        ).payload
      end
      strong_memoize_attr :payload

      def validate_source!
        Ai::AmazonQValidateCommandSourceService.new(command: command, source: source).validate
      end

      def validate_cloud_connector_token!
        return if cloud_connector_token.present?

        raise CloudConnectorTokenError, "Unable to generate valid cloud connector token for #{service_name}"
      end

      def validate_code_position!
        position = note&.position

        raise ArgumentError, "Invalid code position" if position.nil?
        raise ArgumentError, "Invalid code position" if position.start_sha.nil? || position.head_sha.nil?
        raise ArgumentError, "Unknown code line position" unless line_position_for_comment
      end

      def use_existing_thread?
        %w[dev fix review transform].include?(command)
      end

      def reply_only?
        %w[fix].include?(command)
      end

      def create_note_if_needed
        return if use_existing_thread?

        create_note
      end

      def line_position_for_comment
        return unless note&.position

        if note.position.line_range.present?
          {
            comment_start_line: note.position.line_range.dig("start", "new_line").to_s,
            comment_end_line: note.position.line_range.dig("end", "new_line").to_s
          }
        elsif note.position.new_line.present?
          {
            comment_start_line: note.position.new_line.to_s,
            comment_end_line: note.position.new_line.to_s
          }
        end
      end
      strong_memoize_attr :line_position_for_comment

      def create_auth_grant_new
        OauthAccessGrant.create!(
          resource_owner_id: ai_settings.amazon_q_service_account_user_id,
          application_id: ai_settings.amazon_q_oauth_application_id,
          redirect_uri: Gitlab::Routing.url_helpers.root_url,
          expires_in: 1.hour,
          scopes: Gitlab::Auth::Q_SCOPES + dynamic_user_scope,
          organization: Gitlab::Current::Organization.new(user: user).organization
        ).plaintext_token
      end

      def dynamic_user_scope
        ["user:#{user.id}"]
      end

      def create_note
        @progress_note = ::Ai::AmazonQ::CreateNoteService.new(
          author: amazon_q_service_account,
          note: note,
          source: source,
          command: command
        ).execute
      end

      def update_failure_note
        if @progress_note.nil?
          @progress_note = Notes::CreateService.new(
            source.project,
            amazon_q_service_account,
            author: amazon_q_service_account,
            noteable: source,
            note: failure_message,
            discussion_id: note&.discussion_id
          ).execute
        else
          update_note_params = { note: failure_message }

          Notes::UpdateService.new(
            source.project,
            amazon_q_service_account,
            update_note_params
          ).execute(@progress_note)
        end
      end

      def failure_message
        msg = s_("AmazonQ|Sorry, I'm not able to complete the request at this moment. Please try again later.")
        request_id = Labkit::Correlation::CorrelationId.current_id
        msg + format("\n\nRequest ID: %{request_id}", request_id: request_id)
      end

      def amazon_q_service_account
        Ai::Setting.instance.amazon_q_service_account_user
      end
      strong_memoize_attr :amazon_q_service_account

      def validate_service_account!
        if amazon_q_service_account.blank?
          raise ServiceAccountError,
            "#{command} failed due to Amazon Q service account ID is not configured"
        elsif !amazon_q_service_account.composite_identity_enforced?
          raise CompositeIdentityEnforcedError,
            "Cannot find the service account with composite identity enabled"
        end

        true
      end

      def add_service_account_to_project
        ::Ai::AmazonQ::ServiceAccountMemberAddService.new(source.project).execute
      end

      def validate_command!
        # Check the discussions involved in the reply.
        return true unless reply_only?

        # Filter only notes authored by the Amazon Q service user.
        # Search for any of the keywords relating to review findings in the note.
        comments = search_comments_by_service_account(REVIEW_FINDING_KEYWORDS)
        return true unless comments.blank?

        raise MissingPrerequisiteError,
          "#{command} can only be executed as a response to the review command"
      end

      def search_comments_by_service_account(keywords = nil)
        filtered_notes = service_account_notes

        return filtered_notes if keywords.blank?

        keywords = Array(keywords).map(&:downcase)

        filtered_notes.select do |note|
          note_content = note.note.to_s.downcase
          keywords.any? { |keyword| note_content.include?(keyword) }
        end
      end

      def handle_note_error(error_message)
        return unless note

        note.errors.add(:quick_action, "command /q: #{error_message}")
      end

      def service_account_notes
        source.notes.authored_by(amazon_q_service_account).find_discussion(discussion_id)&.notes.to_a
      end
      strong_memoize_attr :service_account_notes

      def ai_settings
        Ai::Setting.instance
      end
      strong_memoize_attr :ai_settings
    end
  end
end
