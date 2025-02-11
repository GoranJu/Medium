# frozen_string_literal: true

module Gitlab
  module Auth
    module Saml
      class SsoState
        SESSION_STORE_KEY = :active_instance_sso_sign_ins
        DEFAULT_PROVIDER_ID = 'default'

        attr_reader :provider_id

        def initialize(provider_id: DEFAULT_PROVIDER_ID)
          @provider_id = provider_id.to_s.downcase.strip
        end

        def active?
          sessionless? || last_signin_at
        end

        def active_since?(cutoff)
          return true if sessionless?
          return false unless active?

          cutoff ? last_signin_at.after?(cutoff) : active?
        end

        def update_active(time: Time.current)
          active_session_data[provider_id] ||= {}
          active_session_data[provider_id]['last_signin_at'] = time
        end

        private

        def active_session_data
          Gitlab::NamespacedSessionStore.new(SESSION_STORE_KEY)
        end

        def sessionless?
          !active_session_data.initiated?
        end

        def last_signin_at
          return if active_session_data[provider_id].nil?

          active_session_data[provider_id]['last_signin_at']
        end
      end
    end
  end
end
