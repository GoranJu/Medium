# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Checks::SecretsCheck, feature_category: :secret_detection do
  include_context 'secrets check context'

  subject(:secrets_check) { described_class.new(changes_access) }

  describe '#validate!' do
    context 'when application setting is disabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: false)
      end

      it_behaves_like 'skips the push check'
    end

    context 'when application setting is enabled' do
      before do
        Gitlab::CurrentSettings.update!(secret_push_protection_available: true)
      end

      context 'when project setting is disabled' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: false)
        end

        it_behaves_like 'skips the push check'
      end

      context 'when project setting is enabled' do
        before do
          project.security_setting.update!(secret_push_protection_enabled: true)
        end

        context 'when license is not ultimate' do
          it_behaves_like 'skips the push check'
        end

        context 'when license is ultimate' do
          before do
            stub_licensed_features(secret_push_protection: true)
          end

          context 'when SDS should be called (on SaaS)' do
            before do
              stub_saas_features(secret_detection_service: true)
              stub_application_setting(secret_detection_service_url: 'https://example.com')
            end

            context 'when instance is Dedicated (temporarily not using SDS)' do
              before do
                stub_application_setting(gitlab_dedicated_instance: true)
              end

              it_behaves_like 'skips sending requests to the SDS' do
                let(:is_dedicated) { true }
              end
            end

            context 'when instance is GitLab.com' do
              it_behaves_like 'skips sending requests to the SDS'

              context 'when `use_secret_detection_service` feature flag is enabled' do
                # this is the happy path (as FFs are enabled by default)
                it_behaves_like 'sends requests to the SDS' do
                  let(:sds_ff_enabled) { true }

                  before do
                    stub_feature_flags(use_secret_detection_service: true)
                  end
                end
              end
            end
          end

          context 'when SDS should not be called (Self-Managed)' do
            it_behaves_like 'skips sending requests to the SDS' do
              let(:saas_feature_enabled) { false }
            end
          end

          context 'when deleting the branch' do
            # We instantiate the described class with delete_changes_access object to ensure
            # this spec example works as it uses repository.blank_ref to denote a branch deletion.
            subject(:secrets_check) { described_class.new(delete_changes_access) }

            it_behaves_like 'skips the push check'
          end

          context 'when the spp_scan_diffs flag is disabled' do
            before do
              stub_feature_flags(spp_scan_diffs: false)
            end

            it_behaves_like 'entire file scan passed'
            it_behaves_like 'scan detected secrets'
            it_behaves_like 'scan detected secrets but some errors occured'
            it_behaves_like 'scan timed out'
            it_behaves_like 'scan failed to initialize'
            it_behaves_like 'scan failed with invalid input'
            it_behaves_like 'scan skipped due to invalid status'
            it_behaves_like 'scan skipped when a commit has special bypass flag'
            it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
            it_behaves_like 'scan discarded secrets because they match exclusions'
            it_behaves_like 'detects secrets with special characters in full files'
          end

          context 'when the spp_scan_diffs flag is enabled' do
            it_behaves_like 'diff scan passed'
            it_behaves_like 'scan detected secrets in diffs'
            it_behaves_like 'detects secrets with special characters in diffs'

            it 'tracks and recovers errors when getting diff' do
              expect(repository).to receive(:diff_blobs).and_raise(::GRPC::InvalidArgument)
              expect(::Gitlab::ErrorTracking).to receive(:track_exception).with(instance_of(::GRPC::InvalidArgument))
              expect(secret_detection_logger).to receive(:error)
                .once
                .with({ "message" => error_messages[:invalid_input_error], "class" => "Gitlab::Checks::SecretsCheck" })

              allow(secret_detection_logger).to receive(:info)
              expect { secrets_check.validate! }.not_to raise_error
            end

            context 'when the protocol is web' do
              subject(:secrets_check) { described_class.new(changes_access_web) }

              it_behaves_like 'entire file scan passed'
              it_behaves_like 'scan detected secrets'
              it_behaves_like 'scan detected secrets but some errors occured'
              it_behaves_like 'scan timed out'
              it_behaves_like 'scan failed to initialize'
              it_behaves_like 'scan failed with invalid input'
              it_behaves_like 'scan skipped due to invalid status'
              it_behaves_like 'scan skipped when a commit has special bypass flag'
              it_behaves_like 'scan skipped when secret_push_protection.skip_all push option is passed'
              it_behaves_like 'scan discarded secrets because they match exclusions'
              it_behaves_like 'detects secrets with special characters in full files'
            end

            context 'when the spp_scan_diffs flag is enabled' do
              it_behaves_like 'diff scan passed'
              it_behaves_like 'scan detected secrets in diffs'
              it_behaves_like 'processes hunk headers'
              it_behaves_like 'detects secrets with special characters in diffs'

              context 'when the protocol is web' do
                subject(:secrets_check) { described_class.new(changes_access_web) }

                it_behaves_like 'entire file scan passed'
                it_behaves_like 'scan detected secrets'
                it_behaves_like 'detects secrets with special characters in full files'
              end
            end
          end
        end
      end
    end
  end

  # While we prefer not to test private methods directly, the structure of the shared examples
  # makes testing this code difficult and time-sonsuming.
  # Remove this if refactoring the shared exazmples makes this easier through testing public methods
  describe '#get_project_security_exclusion_from_sds_exclusion' do
    let_it_be(:project) { create(:project) }
    let_it_be(:pse) { create(:project_security_exclusion, :with_rule, project: project) }

    let(:sds_exclusion) do
      Gitlab::SecretDetection::GRPC::Exclusion.new(
        exclusion_type: Gitlab::SecretDetection::GRPC::ExclusionType::EXCLUSION_TYPE_RULE,
        value: pse.value
      )
    end

    it 'returns the same object if it is a ProjectSecurityExclusion' do
      result = secrets_check.send(:get_project_security_exclusion_from_sds_exclusion, pse)
      expect(result).to be pse
    end

    it 'returns the ProjectSecurityExclusion with the same value' do
      result = secrets_check.send(:get_project_security_exclusion_from_sds_exclusion, sds_exclusion)
      expect(result).to eq pse
    end
  end

  # Most of the shared examples exercise build_payload normally, but this tests it specifically for
  # a situation where the data is not a valid utf8 string after being forced into one.
  # Remove this if refactoring the shared exazmples makes this easier through testing public methods
  describe '#build_payload' do
    context 'when data has invalid encoding' do
      let(:datum_id) { 'test-blob-id' }
      let(:datum_offset) { 1 }
      let(:original_encoding) { 'ASCII-8BIT' }

      let(:data_content) { +'encoded string' }

      let(:invalid_datum) do
        {
          id: datum_id,
          data: data_content,
          offset: datum_offset
        }
      end

      it 'returns nil and logs a warning' do
        expect(data_content).to receive(:encoding).and_return(original_encoding)
        expect(data_content).to receive(:dup).and_return(data_content)
        expect(data_content).to receive(:force_encoding).and_return(data_content)
        expect(data_content).to receive(:valid_encoding?).and_return(false)

        expect(secret_detection_logger).to receive(:warn)
          .with({ "message" => format(log_messages[:invalid_encoding], { encoding: original_encoding }),
            "class" => "Gitlab::Checks::SecretsCheck" })

        result = secrets_check.send(:build_payload, invalid_datum)
        expect(result).to be_nil
      end
    end
  end
end
