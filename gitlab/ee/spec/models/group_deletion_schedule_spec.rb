# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GroupDeletionSchedule do
  describe 'Associations' do
    it { is_expected.to belong_to :group }
    it { is_expected.to belong_to(:deleting_user).class_name('User').with_foreign_key('user_id') }
  end

  describe 'Validations' do
    it { is_expected.to validate_presence_of(:marked_for_deletion_on) }

    context 'when containing linked security policy project' do
      subject(:deletion_schedule) { group.build_deletion_schedule.tap(&:validate) }

      let_it_be(:group) { create(:group) }
      let_it_be(:subgroup) { create(:group, parent: group) }
      let_it_be(:policy_project) { create(:project, group: subgroup) }
      let_it_be(:policy_configuration) do
        create(
          :security_orchestration_policy_configuration,
          namespace: subgroup,
          project: nil,
          security_policy_management_project: policy_project
        )
      end

      context 'with licensed feature' do
        before do
          stub_licensed_features(security_orchestration_policies: true)
        end

        specify do
          expect(deletion_schedule.errors[:base])
            .to include('Group cannot be deleted because it has projects that are linked as a security policy project')
        end

        context 'with feature disabled' do
          before do
            stub_feature_flags(reject_security_policy_project_deletion_groups: false)
          end

          specify do
            expect(deletion_schedule.errors[:base]).to be_empty
          end
        end
      end

      context 'without licensed feature' do
        specify do
          expect(deletion_schedule.errors[:base]).to be_empty
        end
      end
    end
  end
end
