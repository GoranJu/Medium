# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::ServiceAccountMemberAddService, feature_category: :duo_workflow do
  let_it_be(:service_account) { create(:user) }
  let(:project) { create(:project) }
  let(:service) { described_class.new(project) }

  describe '#execute' do
    before do
      Ai::Setting.instance.update!(amazon_q_service_account_user_id: service_account.id)
    end

    context 'when the service account is not a member of the project' do
      it 'adds the service account as a developer' do
        expect { service.execute }.to change { project.members.count }.by(1)

        member = project.members.last
        expect(member.user_id).to eq(service_account.id)
        expect(member.access_level).to eq(Gitlab::Access::DEVELOPER)
      end

      it 'returns a success response' do
        result = service.execute

        expect(result).to be_success
        expect(result.payload).to be_a(ProjectMember)
      end
    end

    context 'when the service account is already a member of the project' do
      before do
        project.add_developer(service_account)
      end

      it 'does not add a new membership' do
        expect { service.execute }.not_to change { project.members.count }
      end

      it 'returns a success response with a message' do
        result = service.execute

        expect(result).to be_success
        expect(result.message).to eq("Membership already exists. Nothing to do.")
      end
    end
  end
end
