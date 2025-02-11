# frozen_string_literal: true

module GitlabSubscriptions
  module MemberManagement
    module BlockSeatOverages
      class << self
        def block_seat_overages?(source)
          root_namespace = source.root_ancestor
          return root_namespace.block_seat_overages? if gitlab_com_subscription?

          block_seat_overages_for_self_managed?
        end

        def seats_available_for?(source, invites, access_level, member_role_id)
          root_namespace = source.root_ancestor
          parsed_invites = process_invites(source, invites)
          if gitlab_com_subscription?
            return root_namespace.seats_available_for?(parsed_invites, access_level, member_role_id)
          end

          seats_available_for_self_managed?(parsed_invites, access_level, member_role_id)
        end

        def non_billable_member?(access_level, member_role_id, exclude_guests)
          if member_role_id
            custom_role = MemberRole.find_by_id(member_role_id)
            custom_role && !custom_role.occupies_seat?
          else
            access_level == ::Gitlab::Access::MINIMAL_ACCESS ||
              (access_level == ::Gitlab::Access::GUEST && exclude_guests)
          end
        end

        private

        def process_invites(source, list)
          emails, user_ids = parse_input_list(list)
          users = user_ids.present? ? User.id_in(user_ids) : []
          existing_users, non_existent_emails = process_emails(source, emails)

          all_users = (users + existing_users).uniq
          human_user_ids = human_users(all_users)

          human_user_ids + non_existent_emails
        end

        def parse_input_list(list)
          emails = []
          user_ids = []
          list.each do |item|
            case item
            when Integer
              user_ids << item
            when /\A\d+\Z/
              user_ids << item.to_i
            when Devise.email_regexp
              emails << item
            end
          end

          [emails, user_ids]
        end

        def process_emails(source, emails)
          case_insensitive_emails = emails.map(&:downcase).uniq
          users_by_emails = source.users_by_emails(case_insensitive_emails)
          existing_users = users_by_emails.values.compact
          non_existent_emails = case_insensitive_emails.select { |email| users_by_emails[email].nil? }

          [existing_users, non_existent_emails]
        end

        def human_users(users)
          human_users = users.select(&:human?)

          human_users.map { |user| user.id.to_s }
        end

        def block_seat_overages_for_self_managed?
          ::Gitlab::CurrentSettings.seat_control_block_overages?
        end

        def seats_available_for_self_managed?(invites, access_level, member_role_id)
          exclude_guests = ::License.current.exclude_guests_from_active_count?
          return true if non_billable_member?(access_level, member_role_id, exclude_guests)

          billable_ids = get_billable_user_ids
          new_invites = invites - billable_ids

          return true if new_invites.empty?

          ::License.current.seats >= (billable_ids.count + new_invites.count)
        end

        def get_billable_user_ids
          ::User.billable.select(:id).map { |user| user.id.to_s }
        end

        def gitlab_com_subscription?
          ::Gitlab::Saas.feature_available?(:gitlab_com_subscriptions)
        end
      end
    end
  end
end
