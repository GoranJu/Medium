# frozen_string_literal: true

module SecretsManagement
  class SecretsManagerClient
    include Gitlab::Utils::StrongMemoize

    SERVER_VERSION_FILE = 'GITLAB_OPENBAO_VERSION'
    KV_VALUE_FIELD = 'value'

    ApiError = Class.new(StandardError)
    ConnectionError = Class.new(StandardError)
    Configuration = Struct.new(:host, :base_path)

    def self.configuration
      @configuration ||= Configuration.new
    end

    def self.configure
      yield(configuration)
    end

    def self.expected_server_version
      path = Rails.root.join(SERVER_VERSION_FILE)
      path.read.chomp
    end

    def enable_secrets_engine(mount_path, type)
      make_request(:post, "sys/mounts/#{mount_path}", { type: type })
    end

    def disable_secrets_engine(mount_path)
      make_request(:delete, "sys/mounts/#{mount_path}")
    end

    def list_secrets(mount_path, secret_path)
      result = make_request(:list, "#{mount_path}/metadata/#{secret_path}", {}, optional: true)
      return [] unless result

      # This N+1 query is temporary until https://github.com/openbao/openbao/pull/766 is merged.
      result["data"]["keys"].filter_map do |key|
        metadata = read_secret_metadata(mount_path, "#{secret_path}/#{key}")
        next unless metadata

        secret_data = { "key" => key, "metadata" => metadata }

        if block_given?
          yield(secret_data)
        else
          secret_data
        end
      end
    end

    def read_secret_metadata(mount_path, secret_path)
      result = make_request(:get, "#{mount_path}/metadata/#{secret_path}", {}, optional: true)
      return unless result

      result["data"]
    end

    def create_kv_secret(mount_path, secret_path, value, custom_metadata = {})
      result = make_request(
        :post,
        "#{mount_path}/data/#{secret_path}",
        {
          data: { KV_VALUE_FIELD => value },
          options: {
            cas: 0
          }
        }
      )

      return result unless custom_metadata&.any?

      # NOTE: This is only temporary. Once OpenBao has the endpoint for
      # creating a secret and its metadata in one transaction, we will
      # use that instead.
      make_request(
        :post,
        "#{mount_path}/metadata/#{secret_path}",
        {
          custom_metadata: custom_metadata
        }
      )
    end

    def delete_kv_secret(mount_path, secret_path)
      make_request(:delete, "#{mount_path}/metadata/#{secret_path}")
    end

    def get_policy(name)
      policy = read_raw_policy name
      return AclPolicy.new(name) if policy.nil?

      parsed = Gitlab::Json.parse(policy["policy"])
      AclPolicy.build_from_hash(name, parsed)
    end

    def set_policy(policy)
      save_raw_policy(policy.name, policy.to_openbao_attributes.to_json)
    end

    def delete_policy(name)
      make_request(
        :delete,
        "sys/policies/acl/#{name}",
        {},
        optional: true
      )
    end

    private

    # save_raw_policy and read_raw_policy handle raw (direct API responses)
    # and the get_policy/set_policy forms should be preferred as they return
    # typed (JSON-able) policies. The risk with these endpoints is that
    # direct usage with HCL will result in non-JSON-parseable policies that
    # cannot be easily modified by Rails.
    def save_raw_policy(name, value)
      make_request(
        :post,
        "sys/policies/acl/#{name}",
        {
          policy: value
        }
      )
    end

    def read_raw_policy(name)
      body = make_request(:get, "sys/policies/acl/#{name}", {}, optional: true)
      body["data"] if body
    end

    def connection
      Faraday.new(url: URI.join(configuration.host, configuration.base_path)) do |f|
        f.request :json
        f.response :json
      end
    end
    strong_memoize_attr(:connection)

    def make_request(method, url, params = {}, optional: false)
      response = case method
                 when :get
                   connection.get(url, params)
                 when :list
                   connection.get(url, params.merge(list: true))
                 when :delete
                   connection.delete(url, params)
                 else
                   connection.post(url, params)
                 end

      body = response.body

      raise ApiError, body["errors"].to_sentence if body && body["errors"]&.any?

      if response.status == 404
        raise ApiError, 'not found' unless optional

        return
      end

      body
    rescue ::Faraday::Error => e
      raise ConnectionError, e.message
    end

    def configuration
      self.class.configuration
    end
  end
end
