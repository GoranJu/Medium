# frozen_string_literal: true

require 'spec_helper'

RSpec.describe SoftwareLicensePolicy, feature_category: :software_composition_analysis do
  subject(:software_license_policy) { build(:software_license_policy) }

  describe 'associations' do
    it { is_expected.to belong_to(:project) }
    it { is_expected.to belong_to(:software_license) }
    it { is_expected.to belong_to(:custom_software_license) }
    it { is_expected.to belong_to(:scan_result_policy_read) }
    it { is_expected.to belong_to(:approval_policy_rule) }
  end

  describe 'validations' do
    it { is_expected.to include_module(Presentable) }
    it { is_expected.to validate_presence_of(:project) }
    it { is_expected.to validate_presence_of(:classification) }
    it { is_expected.to validate_length_of(:software_license_spdx_identifier).is_at_most(255) }

    context 'when not associated with a software_license or custom_software_license' do
      subject { build(:software_license_policy, software_license: nil, custom_software_license: nil) }

      it { is_expected.not_to be_valid }
    end

    context 'when associated with a software_license' do
      subject { create(:software_license_policy, software_license: build(:software_license), custom_software_license: nil) }

      it { is_expected.to be_valid }

      it { is_expected.to validate_uniqueness_of(:software_license).scoped_to([:project_id, :scan_result_policy_id]).with_message(/has already been taken/) }
    end

    context 'when associated with a custom_software_license' do
      subject { build(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license) }

      let_it_be(:project) { create(:project) }
      let_it_be(:custom_software_license) { create(:custom_software_license) }

      it { is_expected.to be_valid }

      context 'when uniqueness is enforced' do
        before do
          create(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license)
        end

        context 'with same custom_license, project, and scan_result_policy' do
          let(:message) { 'Custom software license has already been taken' }

          it 'disallows on create' do
            another_software_license_policy = build(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license)

            expect(another_software_license_policy).not_to be_valid
            expect(another_software_license_policy.errors.full_messages).to include(message)
          end
        end
      end
    end

    context 'when associated with both software_license and custom_software_license' do
      subject { build(:software_license_policy, project: project, software_license: software_license, custom_software_license: custom_software_license) }

      let_it_be(:project) { create(:project) }
      let_it_be(:software_license) { create(:software_license) }
      let_it_be(:custom_software_license) { create(:custom_software_license) }

      it { is_expected.to be_valid }
    end
  end

  describe ".with_license_by_name" do
    subject { described_class.with_license_by_name(name) }

    context 'when the feature flag static_licenses is disabled' do
      before do
        stub_feature_flags(static_licenses: false)
      end

      let!(:mit_policy) { create(:software_license_policy, software_license: mit) }
      let!(:mit) { create(:software_license, :mit) }
      let!(:apache_policy) { create(:software_license_policy, software_license: apache) }
      let!(:apache) { create(:software_license, :apache_2_0) }

      context 'with an exact match' do
        let(:name) { mit.name }

        it { is_expected.to match_array([mit_policy]) }
      end

      context 'with a case insensitive match' do
        let(:name) { 'mIt lICENSE' }

        it { is_expected.to match_array([mit_policy]) }
      end

      context 'with multiple names' do
        let(:name) { [mit.name, apache.name] }

        it { is_expected.to match_array([mit_policy, apache_policy]) }
      end
    end

    context 'when the feature flag static_licenses is enabled' do
      let(:mit_license_name) { 'MIT License' }
      let(:mit_license_spdx_identifier) { 'MIT' }
      let!(:mit_policy) { create(:software_license_policy, software_license_spdx_identifier: mit_license_spdx_identifier) }

      let(:apache_license_name) { 'Apache License 2.0' }
      let(:apache_license_spdx_identifier) { 'Apache-2.0' }
      let!(:apache_policy) { create(:software_license_policy, software_license_spdx_identifier: apache_license_spdx_identifier) }

      context 'with an exact match' do
        let(:name) { mit_license_name }

        it { is_expected.to match_array([mit_policy]) }
      end

      context 'with a case insensitive match' do
        let(:name) { 'mIt lICENSE' }

        it { is_expected.to match_array([mit_policy]) }
      end

      context 'with multiple names' do
        let(:name) { [mit_license_name, apache_license_name] }

        it { is_expected.to match_array([mit_policy, apache_policy]) }
      end
    end
  end

  describe ".with_license_or_custom_license_by_name" do
    subject { described_class.with_license_or_custom_license_by_name(name) }

    context 'when related to a custom software license' do
      let_it_be(:custom_software_license) { create(:custom_software_license, name: 'Custom-License') }
      let_it_be(:custom_software_license_policy) do
        create(:software_license_policy,
          project: custom_software_license.project,
          software_license: nil,
          custom_software_license: custom_software_license)
      end

      let_it_be(:other_custom_software_license) { create(:custom_software_license, name: 'Other-Custom-License') }
      let_it_be(:other_custom_software_license_policy) do
        create(:software_license_policy,
          project: other_custom_software_license.project,
          software_license: nil,
          custom_software_license: other_custom_software_license)
      end

      context 'with an exact match' do
        let(:name) { custom_software_license.name }

        it { is_expected.to match_array([custom_software_license_policy]) }
      end

      context 'with a case insensitive match' do
        let(:name) { 'cuStom-LiCensE' }

        it { is_expected.to match_array([custom_software_license_policy]) }
      end

      context 'with multiple custom names' do
        let(:name) { [custom_software_license.name, other_custom_software_license.name] }

        it { is_expected.to match_array([custom_software_license_policy, other_custom_software_license_policy]) }
      end
    end
  end

  describe ".by_spdx" do
    context 'when the feature flag static_licenses is disabled' do
      before do
        stub_feature_flags(static_licenses: false)
      end

      let_it_be(:mit) { create(:software_license, :mit) }
      let_it_be(:mit_policy) { create(:software_license_policy, software_license: mit) }
      let_it_be(:apache) { create(:software_license, :apache_2_0) }
      let_it_be(:apache_policy) { create(:software_license_policy, software_license: apache) }

      it { expect(described_class.by_spdx(mit.spdx_identifier)).to match_array([mit_policy]) }
      it { expect(described_class.by_spdx([mit.spdx_identifier, apache.spdx_identifier])).to match_array([mit_policy, apache_policy]) }
      it { expect(described_class.by_spdx(SecureRandom.uuid)).to be_empty }
    end

    context 'when the feature flag static_licenses is enabled' do
      let_it_be(:mit_license_spdx_identifier) { 'MIT' }
      let_it_be(:mit_policy) { create(:software_license_policy, software_license_spdx_identifier: mit_license_spdx_identifier) }

      let_it_be(:apache_license_spdx_identifier) { 'Apache-2.0' }
      let_it_be(:apache_policy) { create(:software_license_policy, software_license_spdx_identifier: apache_license_spdx_identifier) }

      it { expect(described_class.by_spdx(mit_license_spdx_identifier)).to match_array([mit_policy]) }
      it { expect(described_class.by_spdx([mit_license_spdx_identifier, apache_license_spdx_identifier])).to match_array([mit_policy, apache_policy]) }
      it { expect(described_class.by_spdx(SecureRandom.uuid)).to be_empty }
    end
  end

  describe '.exclusion_allowed' do
    let_it_be(:mit) { create(:software_license, :mit) }
    let_it_be(:scan_result_policy_read_with_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: true) }
    let_it_be(:scan_result_policy_read_without_inclusion) { create(:scan_result_policy_read, match_on_inclusion_license: false) }
    let!(:mit_policy) { create(:software_license_policy, software_license: mit) }
    let!(:mit_policy_with_inclusion) { create(:software_license_policy, software_license: mit, scan_result_policy_read: scan_result_policy_read_with_inclusion) }
    let!(:mit_policy_without_inclusion) { create(:software_license_policy, software_license: mit, scan_result_policy_read: scan_result_policy_read_without_inclusion) }

    it { expect(described_class.exclusion_allowed).to eq([mit_policy_without_inclusion]) }
  end

  describe "#name" do
    context 'when the feature flag custom_software_license is disabled' do
      before do
        stub_feature_flags(custom_software_license: false)
      end

      specify { expect(subject.name).to eql(subject.software_license.name) }
    end

    context 'when the feature flag custom_software_license is enabled' do
      before do
        stub_feature_flags(custom_software_license: true)
      end

      context 'when associated with a custom_software_license' do
        subject(:software_license_policy) { build(:software_license_policy, project: project, software_license: nil, custom_software_license: custom_software_license) }

        let_it_be(:project) { create(:project) }
        let_it_be(:custom_software_license) { create(:custom_software_license) }

        specify { expect(software_license_policy.name).to eql(software_license_policy.custom_software_license.name) }
      end
    end
  end

  describe "#approval_status" do
    where(:classification, :approval_status) do
      [
        %w[allowed allowed],
        %w[denied denied]
      ]
    end

    with_them do
      subject { build(:software_license_policy, classification: classification) }

      it { expect(subject.approval_status).to eql(approval_status) }
    end
  end

  describe "#spdx_identifier" do
    subject { software_license_policy.spdx_identifier }

    context 'when associated with a custom_software_license' do
      let_it_be(:custom_software_license) { create(:custom_software_license) }
      let(:software_license_policy) { build(:software_license_policy, software_license: nil, custom_software_license: custom_software_license) }

      it { is_expected.to be_nil }
    end

    context 'when associated with a software_license' do
      context 'when the feature flag static_licenses is disabled' do
        before do
          stub_feature_flags(static_licenses: false)
        end

        let(:software_license_policy) { build(:software_license_policy, software_license: software_license, custom_software_license: nil) }

        context 'when software_license does not have an spdx_identifier' do
          let(:software_license) { create(:software_license, spdx_identifier: nil) }

          it { is_expected.to be_nil }
        end

        context 'when software_license has an spdx_identifier' do
          let(:software_license) { create(:software_license, :mit) }

          it { is_expected.to eq(software_license.spdx_identifier) }
        end
      end

      context 'when the feature flag static_licenses is enabled' do
        let(:software_license_policy) { build(:software_license_policy, software_license_spdx_identifier: software_license_spdx_identifier, custom_software_license: nil) }

        context 'when software_license does not have an spdx_identifier' do
          let(:software_license_spdx_identifier) { nil }

          it { is_expected.to be_nil }
        end

        context 'when software_license has an spdx_identifier' do
          let(:mit_license_spdx_identifier) { 'MIT' }
          let(:software_license_spdx_identifier) { 'MIT' }

          it { is_expected.to eq(mit_license_spdx_identifier) }
        end
      end
    end
  end
end
