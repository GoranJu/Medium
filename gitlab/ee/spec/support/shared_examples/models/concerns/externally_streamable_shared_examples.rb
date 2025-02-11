# frozen_string_literal: true

RSpec.shared_examples 'includes ExternallyStreamable concern' do
  describe 'validations' do
    it { is_expected.to validate_presence_of(:config) }
    it { is_expected.to validate_presence_of(:category) }
    it { is_expected.to be_a(AuditEvents::ExternallyStreamable) }
    it { is_expected.to validate_length_of(:name).is_at_most(72) }

    context 'when category' do
      it 'is valid' do
        expect(destination).to be_valid
      end

      it 'is nil' do
        destination.category = nil

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages)
          .to match_array(["Category can't be blank"])
      end

      it 'is invalid' do
        expect { destination.category = 'invalid' }.to raise_error(ArgumentError)
      end
    end

    context 'for secret_token' do
      context 'when secret_token is empty' do
        context 'when category is http' do
          it 'secret token is present' do
            destination1 = build(model_factory_name, category: 'http', secret_token: nil)

            expect(destination1).to be_valid
            expect(destination1.secret_token).to be_present
          end
        end

        context 'when category is not http' do
          it 'destination is invalid' do
            destination1 = build(model_factory_name, :aws, secret_token: nil)

            expect(destination1).to be_invalid
            expect(destination1.secret_token).to be_nil
          end
        end

        context 'when category is nil' do
          it 'destination is invalid' do
            destination1 = build(model_factory_name, category: nil, secret_token: nil)
            expect(destination1).to be_invalid
            expect(destination1.secret_token).to be_nil
          end
        end
      end

      context 'when secret_token is not empty' do
        context 'when category is http' do
          context 'when given secret_token is invalid' do
            it 'destination is invalid' do
              destination1 = build(model_factory_name, category: 'http', secret_token: 'invalid')

              expect(destination1).to be_invalid
              expect(destination1.errors)
                .to match_array(['Secret token should have length between 16 to 24 characters.'])
            end
          end

          context 'when given secret_token is valid' do
            it 'destination is valid' do
              destination1 = build(model_factory_name, category: 'http', secret_token: 'valid_secure_token_123')

              expect(destination1).to be_valid
              expect(destination1.secret_token).to eq('valid_secure_token_123')
            end
          end
        end

        context 'when category is not http' do
          it 'secret_token is present' do
            destination1 = build(model_factory_name, :aws, secret_token: 'random_aws_token')

            expect(destination1).to be_valid
            expect(destination1.secret_token).to eq('random_aws_token')
          end
        end

        context 'when category is nil' do
          it 'destination is invalid' do
            destination1 = build(model_factory_name, category: nil, secret_token: 'random_secret_token')
            expect(destination1).to be_invalid
          end
        end
      end
    end

    it_behaves_like 'having unique enum values'

    context 'when config' do
      it 'is invalid' do
        destination.config = 'hello'

        expect(destination).not_to be_valid
        expect(destination.errors.full_messages).to include('Config must be a valid json schema')
      end
    end

    context 'when creating without a name' do
      before do
        allow(SecureRandom).to receive(:uuid).and_return('12345678')
      end

      it 'assigns a default name' do
        destination = build(model_factory_name, name: nil)

        expect(destination).to be_valid
        expect(destination.name).to eq('Destination_12345678')
      end
    end

    context 'when category is http' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, config: { url: http_url, headers: http_headers })
        end

        let(:more_than_allowed_headers) { {} }

        let(:large_string) { "a" * 256 }
        let(:large_url) { "http://#{large_string}.com" }
        let(:header_hash1) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }
        let(:header_hash2) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }
        let(:invalid_properties) { { key1: { value: 'value1', extra: 'extra key value' } } }
        let(:invalid_characters) { { key1: { value: ' leading or trailing space ', active: true } } }
        let(:valid_special_characters) { { 'X-Meta-Custom_header': { value: '"value",commas,' } } }

        before do
          21.times do |i|
            more_than_allowed_headers["Key#{i}"] = { value: "Value#{i}", active: true }
          end
        end

        where(:http_url, :http_headers, :is_valid) do
          nil                   | nil                                                   | false
          'http://example.com'  | nil                                                   | true
          ref(:large_url)       | nil                                                   | false
          'https://example.com' | nil                                                   | true
          'ftp://example.com'   | nil                                                   | false
          nil                   | { key1: 'value1' }                                    | false
          'http://example.com'  | { key1: { value: 'value1', active: true } }           | true
          'http://example.com'  | { key1: { value: ref(:large_string), active: true } } | false
          'http://example.com'  | { key1: { value: 'value1', active: false } }          | true
          'http://example.com'  | {}                                                    | false
          'http://example.com'  | ref(:header_hash1)                                    | true
          'http://example.com'  | { key1: 'value1' }                                    | false
          'http://example.com'  | ref(:header_hash2)                                    | true
          'http://example.com'  | ref(:more_than_allowed_headers)                       | false
          'http://example.com'  | ref(:invalid_properties)                              | false
          'http://example.com'  | ref(:invalid_characters)                              | false
          'http://example.com'  | ref(:valid_special_characters)                        | true
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    context 'when category is aws' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(:audit_events_group_external_streaming_destination, :aws,
            config: { accessKeyXid: access_key, bucketName: bucket, awsRegion: region })
        end

        where(:access_key, :bucket, :region, :is_valid) do
          SecureRandom.hex(8)   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | true
          nil                   | nil                   | nil                    | false
          SecureRandom.hex(8)   | SecureRandom.hex(8)   | nil                    | false
          SecureRandom.hex(8)   | nil                   | SecureRandom.hex(8)    | false
          nil                   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | false
          SecureRandom.hex(7)   | SecureRandom.hex(8)   | SecureRandom.hex(8)    | false
          SecureRandom.hex(8)   | SecureRandom.hex(35) | SecureRandom.hex(8)    | false
          SecureRandom.hex(8)   | SecureRandom.hex(8) | SecureRandom.hex(26)    | false
          "access-id-with-hyphen" | SecureRandom.hex(8) | SecureRandom.hex(8) | false
          SecureRandom.hex(8) | "bucket/logs/test" | SecureRandom.hex(8) | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    context 'when category is gcp' do
      context 'for config schema validation' do
        using RSpec::Parameterized::TableSyntax

        subject(:destination) do
          build(model_factory_name, :gcp,
            config: { googleProjectIdName: project_id, clientEmail: client_email, logIdName: log_id }.compact)
        end

        where(:project_id, :client_email, :log_id, :is_valid) do
          "valid-project-id"     | "abcd@example.com"                         | "audit-events"        | true
          "valid-project-id-1"   | "abcd@example.com"                         | "audit-events"        | true
          "invalid_project_id"   | "abcd@example.com"                         | "audit-events"        | false
          "invalid-project-id-"  | "abcd@example.com"                         | "audit-events"        | false
          "Invalid-project-id"   | "abcd@example.com"                         | "audit-events"        | false
          "1-invalid-project-id" | "abcd@example.com"                         | "audit-events"        | false
          "-invalid-project-id"  | "abcd@example.com"                         | "audit-events"        | false
          "small"                | "abcd@example.com"                         | "audit-events"        | false
          SecureRandom.hex(16)   | "abcd@example.com"                         | "audit-events"        | false

          "valid-project-id"     | "valid_email+mail@mail.com"                | "audit-events"        | true
          "valid-project-id"     | "invalid_email"                            | "audit-events"        | false
          "valid-project-id"     | "invalid@.com"                             | "audit-events"        | false
          "valid-project-id"     | "invalid..com"                             | "audit-events"        | false
          "valid-project-id"     | "abcd#{SecureRandom.hex(120)}@example.com" | "audit-events"        | false

          "valid-project-id"     | "abcd@example.com"                         | "audit_events"        | true
          "valid-project-id"     | "abcd@example.com"                         | "audit.events"        | true
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENTS"        | true
          "valid-project-id"     | "abcd@example.com"                         | "audit_events/123"    | true
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENT@"        | false
          "valid-project-id"     | "abcd@example.com"                         | "AUDIT_EVENT$"        | false
          "valid-project-id"     | "abcd@example.com"                         | "#AUDIT_EVENT"        | false
          "valid-project-id"     | "abcd@example.com"                         | "%audit_events/123"   | false
          "valid-project-id"     | "abcd@example.com"                         | SecureRandom.hex(256) | false

          nil                    | nil                                        | nil                   | false
          "valid-project-id"     | "abcd@example.com"                         | nil                   | true
          "valid-project-id"     | nil                                        | "audit-events"        | false
          nil                    | "abcd@example.com"                         | "audit-events"        | false
        end

        with_them do
          it do
            expect(destination.valid?).to eq(is_valid)
          end
        end
      end
    end

    describe "#assign_default_log_id" do
      context 'when category is gcp' do
        context 'when log id is provided' do
          it 'does not assign default value' do
            destination = create(model_factory_name,
              :gcp,
              config: {
                googleProjectIdName: "project-id",
                clientEmail: "abcd@email.com",
                logIdName: 'non-default-log'
              }
            )

            expect(destination).to be_valid
            expect(destination.errors).to be_empty
            expect(destination.config['logIdName']).to eq('non-default-log')
          end
        end

        context 'when log id is not provided' do
          it 'assigns default value' do
            destination = create(model_factory_name,
              :gcp,
              config: {
                googleProjectIdName: "project-id",
                clientEmail: "abcd@email.com"
              }
            )

            expect(destination).to be_valid
            expect(destination.errors).to be_empty
            expect(destination.config['logIdName']).to eq('audit-events')
          end
        end
      end

      context 'when category is not gcp' do
        it 'does not add logIdName field to config' do
          destination = create(model_factory_name, config: { url: "https://www.example.com" })

          expect(destination).to be_valid
          expect(destination.config.keys).not_to include('logIdName')
        end
      end
    end

    describe '#headers_hash' do
      subject(:destination) do
        create(model_factory_name, config: { url: 'https://example.com', headers: http_headers })
      end

      context 'when there are no headers' do
        let(:http_headers) { nil }

        it 'returns a hash with only secret token' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(1)
          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
            .to eq(destination.secret_token)
        end
      end

      context 'when there is no active header' do
        let(:http_headers) { { key1: { value: 'value1', active: false }, key2: { value: 'value2', active: false } } }

        it 'returns a hash with only secret token' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(1)
          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
            .to eq(destination.secret_token)
        end
      end

      context 'when there are active and inactive headers' do
        let(:http_headers) { { key1: { value: 'value1', active: true }, key2: { value: 'value2', active: false } } }

        it 'returns a hash with active headers and secret token header' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(2)

          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
            .to eq(destination.secret_token)
          expect(headers_hash["key1"]).to eq('value1')
        end
      end

      context 'when secret token header is overwritten' do
        let(:http_headers) do
          { AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY => { value: 'custom_token_overwrite',
                                                                               active: true } }
        end

        it 'returns a hash with original secret token header' do
          headers_hash = destination.headers_hash

          expect(headers_hash.length).to eq(1)
          expect(headers_hash[AuditEvents::ExternallyStreamable::STREAMING_TOKEN_HEADER_KEY])
          .to eq(destination.secret_token)
        end
      end
    end
  end
end
