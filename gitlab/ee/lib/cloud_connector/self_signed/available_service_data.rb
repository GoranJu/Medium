# frozen_string_literal: true

module CloudConnector
  module SelfSigned
    class AvailableServiceData < BaseAvailableServiceData
      extend ::Gitlab::Utils::Override

      class CachingKeyLoader
        delegate :signing_key, to: :class

        class << self
          # Cache the key in process memory so that we don't perform disk IO every time
          # an access token is created. This function should be called lazily the first
          # time the signing key is needed.
          def signing_key
            @signing_key ||= load_signing_key
          end

          private

          def load_signing_key
            key_data = Rails.application.credentials.openid_connect_signing_key

            raise 'Cloud Connector: no key found' unless key_data

            rsa_key = OpenSSL::PKey::RSA.new(key_data)

            ::JWT::JWK.new(rsa_key, kid_generator: ::JWT::JWK::Thumbprint)
          end
        end
      end

      attr_reader :backend

      def initialize(name, cut_off_date, bundled_with, backend)
        super(name, cut_off_date, bundled_with.keys)

        @bundled_with = bundled_with
        @backend = backend
        @key_loader = CachingKeyLoader.new
      end

      override :access_token
      def access_token(resource = nil, extra_claims: {})
        ::Gitlab::CloudConnector::JsonWebToken.new(
          issuer: Doorkeeper::OpenidConnect.configuration.issuer,
          audience: backend,
          subject: Gitlab::CurrentSettings.uuid,
          realm: ::CloudConnector.gitlab_realm,
          scopes: scopes_for(resource),
          ttl: 1.hour,
          extra_claims: extra_claims
        ).encode(@key_loader.signing_key)
      end

      private

      def gitlab_org_group
        @gitlab_org_group ||= Group.find_by_path_or_name('gitlab-org')
      end

      def scopes_for(resource)
        free_access? ? allowed_scopes_during_free_access : allowed_scopes_from_purchased_bundles_for(resource)
      end

      def allowed_scopes_from_purchased_bundles_for(resource)
        add_on_purchases_for(resource).uniq_add_on_names.flat_map do |name|
          # Renaming the code_suggestions add-on to duo_pro would be complex and risky
          # so we are still using the legacy name is parts of the code.
          # The mapping is needed elsewhere because of third-party integrations that rely on our API.
          add_on_name = name == 'code_suggestions' ? 'duo_pro' : name
          @bundled_with[add_on_name]
        end.uniq
      end

      def add_on_purchases_for(resource = nil)
        resource.is_a?(User) ? add_on_purchases_assigned_to(resource) : add_on_purchases(resource)
      end

      def allowed_scopes_during_free_access
        @bundled_with.values.flatten.uniq
      end
    end
  end
end
