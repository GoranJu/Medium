# frozen_string_literal: true

module Users
  module MemberRoles
    class AssignService < BaseService
      attr_accessor :current_user, :params

      def initialize(current_user, params = {})
        @current_user = current_user
        @params = params
      end

      def execute
        unless current_user.can?(:admin_member_role)
          return ServiceResponse.error(message: 'Forbidden', reason: :forbidden)
        end

        unless valid_member_role_param?
          return ServiceResponse.error(
            message: 'Only admin custom roles can be assigned directly to a user.',
            reason: :forbidden
          )
        end

        unless Feature.enabled?(:custom_ability_read_admin_dashboard, current_user)
          return ServiceResponse.error(message: 'Not yet available', reason: :forbidden)
        end

        assign
      end

      private

      def valid_member_role_param?
        return true unless params[:member_role]

        params[:member_role].admin_related_role?
      end

      def assign
        user_member_role = if params[:member_role]
                             Users::UserMemberRole.create(params)
                           else
                             user_role = Users::UserMemberRole.find_by_user_id(params[:user].id)

                             unless user_role
                               return ServiceResponse.error(message: 'No member role exists for the user.')
                             end

                             user_role.destroy!

                             nil
                           end

        ServiceResponse.success(payload: { user_member_role: user_member_role })
      end
    end
  end
end
