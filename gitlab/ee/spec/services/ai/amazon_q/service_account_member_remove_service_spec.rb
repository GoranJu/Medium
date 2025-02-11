# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::ServiceAccountMemberRemoveService, feature_category: :duo_workflow do
  let_it_be(:current_user) { create(:user) }
  let_it_be(:service_account) { create(:user) }
  let_it_be_with_reload(:group) { create(:group) }
  let_it_be_with_reload(:project) { create(:project, namespace: group) }

  let(:service) { described_class.new(current_user, project) }

  shared_examples 'when the service account is a member of the project' do
    before_all do
      project.add_developer(service_account)
    end

    it 'removes the service account membership' do
      expect { service.execute }.to change { project.members.count }.by(-1)
      expect(project.members.find_by(user_id: service_account.id)).to be_nil
    end

    it 'returns a success response' do
      result = service.execute

      expect(result).to be_success
    end

    it 'calls destroy service' do
      # Note: call expected_member first so that it can handle whatever mocks it needs
      member = expected_member

      expect_next_instance_of(Members::DestroyService, current_user) do |destroy_service|
        expect(destroy_service).to receive(:execute).with(
          member,
          skip_authorization: true,
          skip_subresources: false,
          unassign_issuables: false
        )
      end

      service.execute
    end
  end

  describe '#execute' do
    before do
      Ai::Setting.instance.update!(amazon_q_service_account_user_id: service_account.id)
    end

    it_behaves_like 'when the service account is a member of the project' do
      let(:expected_member) { project.members.find_by(user_id: service_account.id) }
    end

    context 'when the service account is not a member of the project' do
      it 'does not remove any membership' do
        expect { service.execute }.not_to change { project.members.count }
      end

      it 'returns a success response with a message' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq("Membership not found. Nothing to do.")
      end
    end

    context 'when the service targets the group' do
      let(:service) { described_class.new(current_user, group) }

      it_behaves_like 'when the service account is a member of the project' do
        let(:expected_member) do
          member = group.members.build(user: service_account)

          # stub `.build` so that we always return the same value which can strengthen our assertion
          # inside the `expected_member` so that the other tests run without this stub, to provide
          # some "integration" coverage
          allow(group.members).to receive(:build).with(user: service_account).and_return(member)

          member
        end
      end

      context 'when the service account is a member of the group' do
        before_all do
          group.add_developer(service_account)
        end

        it 'calls destroy service' do
          expect_next_instance_of(Members::DestroyService, current_user) do |destroy_service|
            expect(destroy_service).to receive(:execute).with(
              group.members.find_by(user: service_account),
              skip_authorization: true,
              skip_subresources: false,
              unassign_issuables: false
            )
          end

          service.execute
        end
      end
    end
  end
end
