# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SecretsManagement::SecretsManagerClient, :gitlab_secrets_manager, feature_category: :secrets_management do
  let(:client) { described_class.new }

  shared_examples_for 'making an invalid API request' do
    it 'raises an error' do
      expect { subject }.to raise_error(SecretsManagement::SecretsManagerClient::ApiError)
    end
  end

  describe '.expected_server_version' do
    it 'returns the content of GITLAB_OPENBAO_VERSION file' do
      path = Rails.root.join(described_class::SERVER_VERSION_FILE)
      version = path.read.chomp

      expect(described_class.expected_server_version).to eq(version)
    end
  end

  describe 'handling connection errors' do
    before do
      webmock_enable!(allow_localhost: false)
      stub_request(:any, %r{#{described_class.configuration.host}/v1/sys/mounts}).to_raise(Errno::ECONNREFUSED)
    end

    after do
      webmock_enable!(allow_localhost: true)
      WebMock.reset!
    end

    it 'raises the error' do
      expect { client.enable_secrets_engine('test', 'kv-v2') }.to raise_error(described_class::ConnectionError)
    end
  end

  describe '#enable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }
    let(:engine) { 'kv-v2' }

    it 'enables the secrets engine' do
      client.enable_secrets_engine(mount_path, engine)

      expect_kv_secret_engine_to_be_mounted(mount_path)
    end
  end

  describe '#disable_secrets_engine' do
    let(:mount_path) { 'some/test/path' }

    it 'disables the secrets engine' do
      client.enable_secrets_engine(mount_path, 'kv-v2')

      expect_kv_secret_engine_to_be_mounted(mount_path)

      client.disable_secrets_engine(mount_path)

      expect_kv_secret_engine_not_to_be_mounted(mount_path)
    end
  end

  describe '#list_secrets' do
    let(:mount_path) { 'some/mount/path' }
    let(:other_mount_path) { 'other/mount/path' }
    let(:secrets_path) { 'secrets' }
    let(:target_mount_path) { mount_path }
    let(:target_secrets_path) { secrets_path }

    before do
      client.enable_secrets_engine(mount_path, 'kv-v2')
      client.enable_secrets_engine(other_mount_path, 'kv-v2')

      client.create_kv_secret(
        mount_path,
        "#{secrets_path}/DBPASS",
        'somevalue',
        {
          environment: 'staging'
        }
      )

      client.create_kv_secret(
        mount_path,
        "other_secrets/APIKEY",
        'somevalue',
        {
          environment: 'staging'
        }
      )

      client.create_kv_secret(
        other_mount_path,
        "#{secrets_path}/DEPLOYKEY",
        'somevalue',
        {
          environment: 'staging'
        }
      )
    end

    subject(:result) { client.list_secrets(target_mount_path, target_secrets_path) }

    it 'returns all matching secrets' do
      expect(result).to contain_exactly(
        a_hash_including(
          "key" => "DBPASS",
          "metadata" => a_hash_including(
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      )
    end

    context 'when mount path does not exist' do
      let(:target_mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when secrets path does not exist' do
      let(:target_secrets_path) { 'something/else' }

      it { is_expected.to eq([]) }
    end

    context 'when block is given' do
      it 'yields each entry and returns in the list the returned value of each block' do
        result = client.list_secrets(mount_path, secrets_path) do |data|
          { new_data: data["key"] }
        end

        expect(result).to contain_exactly(new_data: "DBPASS")
      end
    end
  end

  describe '#read_secret_metadata' do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      client.create_kv_secret(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        {
          environment: 'staging'
        }
      )
    end

    subject(:result) { client.read_secret_metadata(mount_path, secret_path) }

    context 'when the secret exists' do
      it 'returns the metadata' do
        expect(result).to match(
          a_hash_including(
            "custom_metadata" => a_hash_including(
              "environment" => "staging"
            )
          )
        )
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end

    context 'when the secret does not exist' do
      let(:secret_path) { 'something/else' }

      it { is_expected.to be_nil }
    end
  end

  describe '#create_kv_secret' do
    let(:existing_mount_path) { 'some/test/path' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { 'DBPASS' }
    let(:value) { 'somevalue' }

    let(:custom_metadata) do
      {
        environment: 'staging'
      }
    end

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')
    end

    subject(:call_api) { client.create_kv_secret(mount_path, secret_path, value, custom_metadata) }

    context 'when the mount path exists' do
      context 'when the given secret path does not exist' do
        it 'creates the secret and the custom metadata' do
          call_api

          expect_kv_secret_to_have_value(mount_path, secret_path, value)
          expect_kv_secret_to_have_custom_metadata(mount_path, secret_path, custom_metadata.stringify_keys)
        end
      end

      context 'when the given secret path exists' do
        before do
          client.create_kv_secret(mount_path, secret_path, 'someexistingvalue')
        end

        it_behaves_like 'making an invalid API request'
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end

  shared_context 'with policy management' do
    let(:name) { 'project_test' }

    let(:acl_policy) do
      SecretsManagement::AclPolicy.build_from_hash(
        name,
        {
          "path" => {
            "test/secrets/*" => {
              "capabilities" => ["create"],
              "required_parameters" => ["something_required"],
              "allowed_parameters" => {
                "something_allowed" => ["allowed_value"]
              },
              "denied_parameters" => {
                "something_denied" => ["denied_value"]
              }
            }
          }
        }
      )
    end
  end

  describe '#set_policy' do
    include_context 'with policy management'

    subject(:call_api) { client.set_policy(acl_policy) }

    it 'creates the policy' do
      call_api

      policy = client.get_policy(name)
      expect(policy.to_openbao_attributes).to match(
        acl_policy.to_openbao_attributes
      )
    end
  end

  describe '#get_policy' do
    include_context 'with policy management'

    subject(:result) { client.get_policy(name) }

    context 'when the policy exists' do
      before do
        client.set_policy(acl_policy)
      end

      it 'fetches the policy' do
        expect(result.to_openbao_attributes).to match(
          acl_policy.to_openbao_attributes
        )
      end
    end

    context 'when the policy does not exist' do
      it 'returns an empty policy object' do
        expect(result.to_openbao_attributes).to match(path: {})
      end
    end
  end

  describe '#delete_policy' do
    include_context 'with policy management'

    subject(:call_api) { client.delete_policy(name) }

    context 'when the policy exists' do
      before do
        client.set_policy(acl_policy)
      end

      it 'deletes the policy' do
        expect { call_api }.not_to raise_error

        policy = client.get_policy(name)
        expect(policy.to_openbao_attributes).to match(path: {})
      end
    end

    context 'when the policy does not exist' do
      it 'deletes nothing and fails silently' do
        expect { call_api }.not_to raise_error
      end
    end
  end

  describe '#delete_kv_secret' do
    let(:existing_mount_path) { 'secrets' }
    let(:existing_secret_path) { 'DBPASS' }
    let(:mount_path) { existing_mount_path }
    let(:secret_path) { existing_secret_path }

    subject(:call_api) { client.delete_kv_secret(mount_path, secret_path) }

    before do
      client.enable_secrets_engine(existing_mount_path, 'kv-v2')

      client.create_kv_secret(
        existing_mount_path,
        existing_secret_path,
        'somevalue',
        {
          environment: 'staging'
        }
      )
    end

    context 'when the mount path exists' do
      context 'when the given secret path exists' do
        it 'deletes the secret permanently' do
          call_api

          expect_kv_secret_not_to_exist(mount_path, secret_path)
        end
      end

      context 'when the given secret path does not exist' do
        let(:secret_path) { 'SOMETHING_ELSE' }

        it 'does not fail' do
          expect { call_api }.not_to raise_error
        end
      end
    end

    context 'when the mount path does not exist' do
      let(:mount_path) { 'something/else' }

      it_behaves_like 'making an invalid API request'
    end
  end
end
