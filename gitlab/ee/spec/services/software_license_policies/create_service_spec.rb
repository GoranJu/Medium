# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicies::CreateService, feature_category: :security_policy_management do
  let(:project) { create(:project) }
  let(:params) { { name: 'ExamplePL/2.1', approval_status: 'denied' } }

  let(:user) do
    create(:user).tap do |u|
      project.add_maintainer(u)
    end
  end

  before do
    stub_licensed_features(license_scanning: true)
  end

  subject { described_class.new(project, user, params) }

  describe '#execute' do
    shared_examples_for 'when an error occurs during the software license creation' do
      context 'when an error occurs during the software license creation' do
        before do
          allow(SoftwareLicense).to receive(:create!).and_raise(
            ActiveRecord::RecordInvalid.new(SoftwareLicense.new.tap do |r|
              r.errors.add(:base, 'error')
            end))
        end

        it 'returns an error' do
          result

          expect(result[:status]).to be(:error)
          expect(result[:message]).to be_present
          expect(result[:http_status]).to be(400)
        end
      end
    end

    context 'when valid parameters are specified' do
      context 'when custom_software_license feature flag is disabled' do
        let(:license_name) { 'MIT License' }
        let(:license_spdx_identifier) { 'MIT' }
        let(:params) { { name: license_name, approval_status: 'allowed' } }
        let(:result) { subject.execute }

        before do
          stub_feature_flags(custom_software_license: false)
        end

        it 'creates one software license policy correctly' do
          result

          expect(project.software_license_policies.count).to be(1)
          expect(result[:status]).to be(:success)
          expect(result[:software_license_policy]).to be_present
          expect(result[:software_license_policy]).to be_persisted
          expect(result[:software_license_policy].name).to eq(params[:name])
          expect(result[:software_license_policy].classification).to eq(params[:approval_status])
          expect(result[:software_license_policy].spdx_identifier).to eq(license_spdx_identifier)
        end

        context 'when name contains whitespaces' do
          let(:params) { { name: '  MIT   ', approval_status: 'allowed' } }

          it 'creates one software license policy with stripped name' do
            result

            expect(project.software_license_policies.count).to be(1)
            expect(result[:status]).to be(:success)
            expect(result[:software_license_policy]).to be_persisted
            expect(result[:software_license_policy].name).to eq('MIT')
          end
        end

        context 'when a software license with the given name exists' do
          before do
            create(:software_license, name: license_name)
          end

          it 'does not call CustomSoftwareLicense::FindOrCreateService' do
            expect(Security::CustomSoftwareLicenses::FindOrCreateService).not_to receive(:new)

            result
          end

          it 'sets the software license and does not set the custom software license' do
            result

            expect(result[:software_license_policy].software_license.name).to eq(license_name)
            expect(result[:software_license_policy].spdx_identifier).to eq(license_spdx_identifier)
            expect(result[:software_license_policy].custom_software_license).to be_nil
          end
        end

        context 'when the software license does not exists' do
          let(:license_name) { 'Custom License' }

          it 'calls CustomSoftwareLicense::FindOrCreateService' do
            expect_next_instance_of(Security::CustomSoftwareLicenses::FindOrCreateService, project: project,
              params: params) do |service|
              expect(service).to receive(:execute).and_call_original
            end

            result
          end

          it 'sets the expected attributes' do
            result

            expect(result[:software_license_policy].software_license.name).to eq(license_name)
            expect(result[:software_license_policy].custom_software_license.name).to eq(license_name)
            expect(result[:software_license_policy].spdx_identifier).to be_nil
          end

          it_behaves_like 'when an error occurs during the software license creation'
        end
      end

      context 'when custom_software_license feature flag is enabled' do
        before do
          stub_feature_flags(custom_software_license: true)
        end

        let(:license_name) { 'MIT License' }
        let(:license_spdx_identifier) { 'MIT' }
        let(:params) { { name: license_name, approval_status: 'allowed' } }

        subject(:result) { described_class.new(project, user, params).execute }

        context 'when a software license with the given name exists' do
          before do
            create(:software_license, name: license_name)
          end

          it 'does not call CustomSoftwareLicense::FindOrCreateService' do
            expect(Security::CustomSoftwareLicenses::FindOrCreateService).not_to receive(:new)

            result
          end

          it 'creates one software license policy correctly' do
            result

            expect(project.software_license_policies.count).to be(1)
            expect(result[:status]).to be(:success)
            expect(result[:software_license_policy]).to be_present
            expect(result[:software_license_policy]).to be_persisted
            expect(result[:software_license_policy].name).to eq(params[:name])
            expect(result[:software_license_policy].classification).to eq(params[:approval_status])
            expect(result[:software_license_policy].software_license_spdx_identifier).to eq(license_spdx_identifier)
          end

          context 'when the SPDX identifier is not available' do
            before do
              license = ::Gitlab::SPDX::License.new(id: nil, name: "MIT License", deprecated: false)

              allow(::Gitlab::SPDX::Catalogue).to receive(:latest_active_licenses).and_return([license])
            end

            it 'creates one software license policy correctly' do
              result
              expect(project.software_license_policies.count).to be(1)
              expect(result[:status]).to be(:success)
              expect(result[:software_license_policy]).to be_present
              expect(result[:software_license_policy]).to be_persisted
              expect(result[:software_license_policy].name).to eq(params[:name])
              expect(result[:software_license_policy].classification).to eq(params[:approval_status])
              expect(result[:software_license_policy].software_license_spdx_identifier).to be_nil
              expect(result[:software_license_policy].software_license.name).to eq(license_name)
              expect(result[:software_license_policy].software_license.spdx_identifier).to be_nil
              expect(result[:software_license_policy].custom_software_license).to be_nil
            end
          end
        end

        context 'when the software license does not exists' do
          it 'calls CustomSoftwareLicense::FindOrCreateService' do
            expect_next_instance_of(Security::CustomSoftwareLicenses::FindOrCreateService, project: project,
              params: params) do |service|
              expect(service).to receive(:execute).and_call_original
            end

            result
          end

          it 'creates one software license policy correctly' do
            result
            expect(project.software_license_policies.count).to be(1)
            expect(result[:status]).to be(:success)
            expect(result[:software_license_policy]).to be_present
            expect(result[:software_license_policy]).to be_persisted
            expect(result[:software_license_policy].name).to eq(params[:name])
            expect(result[:software_license_policy].classification).to eq(params[:approval_status])
            expect(result[:software_license_policy].software_license_spdx_identifier).to be_nil
            expect(result[:software_license_policy].software_license.name).to eq(license_name)
            expect(result[:software_license_policy].software_license.spdx_identifier).to be_nil
            expect(result[:software_license_policy].custom_software_license.name).to eq(license_name)
          end
        end

        it_behaves_like 'when an error occurs during the software license creation'
      end
    end

    context 'when an argument error is raised' do
      before do
        allow_next_instance_of(Project) do |instance|
          allow(instance).to receive(:software_license_policies).and_raise(ArgumentError)
        end
      end

      specify { expect(subject.execute[:status]).to be(:error) }
      specify { expect(subject.execute[:message]).to be_present }
      specify { expect(subject.execute[:http_status]).to be(400) }
    end

    context 'when invalid input is provided' do
      before do
        params[:approval_status] = nil
      end

      specify { expect(subject.execute[:status]).to be(:error) }
      specify { expect(subject.execute[:message]).to be_present }
      specify { expect(subject.execute[:http_status]).to be(400) }
    end
  end
end
