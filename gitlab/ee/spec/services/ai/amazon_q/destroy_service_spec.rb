# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Ai::AmazonQ::DestroyService, feature_category: :ai_agents do
  describe '#execute' do
    let_it_be(:user) { create(:admin) }
    let_it_be(:service_account) { create(:service_account) }
    let_it_be(:doorkeeper_application) { create(:doorkeeper_application) }
    let_it_be(:role_arn) { SecureRandom.hex }

    before do
      Ai::Setting.instance.update!(
        amazon_q_service_account_user_id: service_account.id,
        amazon_q_oauth_application_id: doorkeeper_application.id,
        amazon_q_ready: true,
        amazon_q_role_arn: role_arn
      )
    end

    subject(:instance) { described_class.new(user) }

    it 'returns ServiceResponse.success' do
      result = instance.execute

      expect(result).to be_a(ServiceResponse)
      expect(result.success?).to be(true)
    end

    context 'when the AI settings update fails' do
      it 'returns ServiceResponse.error with expected error message' do
        ai_settings = Ai::Setting.instance
        allow(Ai::Setting).to receive(:instance).and_return(ai_settings)
        allow(ai_settings).to receive(:update).and_return(false)
        allow(ai_settings).to receive_message_chain(
          :errors, :full_messages, :to_sentence
        ).and_return('Oh oh!')

        expect(instance.execute).to have_attributes(
          success?: false,
          message: 'Oh oh!'
        )
      end
    end

    it 'blocks the service account' do
      expect { instance.execute }.to change { service_account.reload.blocked? }.from(false).to(true)
    end

    it 'destroys the oauth application' do
      instance.execute

      expect { doorkeeper_application.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end

    it 'updates application settings' do
      expect { instance.execute }
        .to change {
          Ai::Setting.instance.amazon_q_oauth_application_id
        }.from(doorkeeper_application.id).to(nil).and change {
          Ai::Setting.instance.amazon_q_ready
        }.from(true).to(false).and change {
          Ai::Setting.instance.amazon_q_role_arn
        }.from(role_arn).to(nil).and not_change {
          Ai::Setting.instance.amazon_q_service_account_user_id
        }
    end

    it 'creates an audit event' do
      expect { instance.execute }.to change { AuditEvent.count }.by(1)
      expect(AuditEvent.last.details).to include(
        event_name: 'q_onbarding_updated',
        custom_message: 'Changed amazon_q_role_arn to null, ' \
          'amazon_q_oauth_application_id to null, ' \
          'amazon_q_ready to null'
      )
    end
  end
end
