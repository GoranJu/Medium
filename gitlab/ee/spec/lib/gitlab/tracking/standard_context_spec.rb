# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Tracking::StandardContext, feature_category: :service_ping do
  let(:snowplow_context) { subject.to_context }

  describe '#to_context' do
    let(:user) { build_stubbed(:user) }
    let(:instance_id) { SecureRandom.uuid }

    before do
      allow(Gitlab::GlobalAnonymousId).to receive(:instance_id).and_return(instance_id)
    end

    subject do
      described_class.new(user: user)
    end

    it 'includes the instance_id' do
      expect(snowplow_context.to_json[:data][:instance_id]).to eq(instance_id)
    end

    context 'on .com' do
      before do
        allow(Gitlab).to receive(:com?).and_return(true)
      end

      it 'sets the realm to saas' do
        expect(snowplow_context.to_json[:data][:realm]).to eq('saas')
      end

      context 'when user is nil' do
        let(:user) { nil }

        it 'sets is_gitlab_team_member to nil' do
          expect(snowplow_context.to_json[:data][:is_gitlab_team_member]).to eq(nil)
        end
      end

      context 'with GitLab team member' do
        before do
          allow(Gitlab::Com).to receive(:gitlab_com_group_member?).with(user.id).and_return(true)
        end

        it 'sets is_gitlab_team_member to true' do
          expect(snowplow_context.to_json[:data][:is_gitlab_team_member]).to eq(true)
        end
      end

      context 'with non GitLab team member' do
        before do
          allow(Gitlab::Com).to receive(:gitlab_com_group_member?).with(user.id).and_return(false)
        end

        it 'sets is_gitlab_team_member to false' do
          expect(snowplow_context.to_json[:data][:is_gitlab_team_member]).to eq(false)
        end
      end
    end

    context 'on self-managed' do
      before do
        allow(Gitlab).to receive(:com?).and_return(false)
      end

      it 'sets the realm to self-managed' do
        expect(snowplow_context.to_json[:data][:realm]).to eq('self-managed')
      end
    end
  end
end
