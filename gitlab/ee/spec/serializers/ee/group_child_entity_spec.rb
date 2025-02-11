# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupChildEntity, feature_category: :groups_and_projects do
  include ExternalAuthorizationServiceHelpers
  include Gitlab::Routing.url_helpers

  let_it_be(:user) { create(:user) }
  let_it_be(:project) { create(:project, :with_sox_compliance_framework) }
  let_it_be(:project_without_compliance_framework) { create(:project) }
  let_it_be(:group) { create(:group) }

  let(:request) { double('request') }
  let(:entity) { described_class.new(object, request: request) }

  subject(:json) { entity.as_json }

  before do
    allow(request).to receive(:current_user).and_return(user)
    stub_commonmark_sourcepos_disabled
  end

  describe 'with compliance framework' do
    shared_examples 'does not have the compliance framework' do
      it do
        expect(json[:compliance_management_frameworks]).to be_nil
      end
    end

    context 'disabled' do
      before do
        stub_licensed_features(compliance_framework: false)
      end

      context 'for a project' do
        let(:object) { project }

        it_behaves_like 'does not have the compliance framework'
      end

      context 'for a group' do
        let(:object) { group }

        it_behaves_like 'does not have the compliance framework'
      end
    end

    describe 'enabled' do
      before do
        stub_licensed_features(compliance_framework: true)
      end

      context 'for a project' do
        let(:object) { project }

        it 'has the compliance framework' do
          expect(json[:compliance_management_frameworks][0]['name']).to eq('SOX')
        end
      end

      context 'for a project without a compliance framework' do
        let(:object) { project_without_compliance_framework }

        it 'returns empty array' do
          expect(json[:compliance_management_frameworks]).to eq([])
        end
      end

      context 'for a group' do
        let(:object) { group }

        it_behaves_like 'does not have the compliance framework'
      end
    end
  end

  describe 'marked_for_deletion' do
    let_it_be(:subgroup) { create(:group, name: 'subgroup', parent: group) }
    let_it_be(:sub_subgroup) { create(:group, name: 'subsubgroup', parent: subgroup) }
    let_it_be(:project) { create(:project, name: 'project 1', group: group) }

    before do
      stub_licensed_features(adjourned_deletion_for_projects_and_groups: true)
      stub_application_setting(deletion_adjourned_period: 14)
    end

    context 'when group is marked for deletion' do
      before_all do
        create(:group_deletion_schedule, group: group, marked_for_deletion_on: Date.today, deleting_user: user)
      end

      it 'returns true for child projects and groups' do
        [group, subgroup, sub_subgroup, project].each do |object|
          expect(described_class.new(object, request: request).as_json[:marked_for_deletion]).to eq(true)
        end
      end
    end

    context 'when group is not marked for deletion' do
      it 'returns false for child projects and groups' do
        [group, subgroup, sub_subgroup, project].each do |object|
          expect(described_class.new(object, request: request).as_json[:marked_for_deletion]).to eq(false)
        end
      end
    end
  end
end
