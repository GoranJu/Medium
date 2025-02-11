# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    class ProcessUserBillablePromotionService < BaseService
      include GitlabSubscriptions::MemberManagement::PromotionManagementUtils

      def initialize(current_user, user, status, skip_authorization = false)
        @current_user = current_user
        @user = user
        @status = status
        @failed_member_approvals = []
        @successful_promotion_count = 0
        @skip_authorization = skip_authorization
      end

      def execute
        return error('Unauthorized') unless authorized?

        case status
        when :denied
          deny_member_approvals
        when :approved
          apply_member_approvals
        else
          error("Invalid #{status}")
        end
      rescue ActiveRecord::ActiveRecordError => e
        Gitlab::AppLogger.error(message: "Failed to update member approval status to #{status}: #{e.message}")
        Gitlab::ErrorTracking.track_exception(e)
        error("Failed to update member approval status to #{status}")
      end

      private

      attr_reader :current_user, :user, :status, :skip_authorization
      attr_accessor :failed_member_approvals, :successful_promotion_count

      def authorized?
        return false unless member_promotion_management_enabled?

        (current_user.present? &&
          current_user.can_admin_all_resources?) || skip_authorization
      end

      def apply_member_approvals
        pending_approvals.find_each do |member_approval|
          response = process_member_approval(member_approval)

          if response[:status] == :error
            failed_member_approvals << member_approval
            Gitlab::AppLogger.error(message: "Failed to apply pending promotions: #{response[:message]}")
          else
            member_approval.update!(status: :approved)
            self.successful_promotion_count += 1
          end
        end

        return error("Failed to apply promotions") if all_promotions_failed?

        approve_failed_member_approvals
        success_status = failed_member_approvals.present? ? :partial_success : :success

        success(success_status)
      end

      def process_member_approval(member_approval)
        source = get_source_from_member_namespace(member_approval.member_namespace)
        params = member_approval_params(member_approval, source)

        ::Members::CreateService.new(current_user, params).execute
      end

      def pending_approvals
        ::Members::MemberApproval.pending_member_approvals_for_user(user.id)
      end

      def all_promotions_failed?
        successful_promotion_count == 0 && failed_member_approvals.present?
      end

      def member_approval_params(member_approval, source)
        params = member_approval.metadata.symbolize_keys
        params.merge!(
          user_id: [user.id],
          source: source,
          access_level: member_approval.new_access_level,
          invite_source: self.class.name,
          skip_authorization: skip_authorization
        )
      end

      def get_source_from_member_namespace(member_namespace)
        case member_namespace
        when ::Namespaces::ProjectNamespace
          member_namespace.project
        when ::Group
          member_namespace
        end
      end

      def deny_member_approvals
        pending_approvals.each_batch do |batch|
          batch.update_all(updated_at: Time.current, status: :denied)
        end

        success
      end

      def approve_failed_member_approvals
        failed_member_approvals.each do |member_approval|
          member_approval.update!(status: :approved)
        end
      end

      def success(result = :success)
        ServiceResponse.success(
          message: "Successfully processed request",
          payload: {
            result: result,
            user: user,
            status: status
          }
        )
      end

      def error(message)
        ServiceResponse.error(
          message: message,
          payload: {
            result: :failed
          }
        )
      end
    end
  end
end
