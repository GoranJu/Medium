# frozen_string_literal: true

require "fast_spec_helper"
require_relative '../../../../app/services/service_response'
require_relative '../../../app/services/remote_development/service_response_factory'
require_relative '../../../app/services/remote_development/common_service'
require_relative '../../../app/services/remote_development/logger'

RSpec.describe ::RemoteDevelopment::CommonService, feature_category: :workspaces do
  let(:domain_main_class) do
    Class.new do
      cattr_accessor :response_hash
      private_class_method :response_hash, :response_hash=

      # @param [Hash] context
      # @return [Hash]
      def self.main(context)
        context => { settings: settings, logger: logger }

        settings.fetch(:some_setting)
        logger.debug("some log")

        response_hash
      end
    end
  end

  let(:arg) { 1 }
  let(:domain_main_class_args) { { arg: arg } }
  let(:settings) { instance_double(Hash, fetch: nil) }
  let(:logger) { instance_double(RemoteDevelopment::Logger, debug: nil) }
  let(:auth_ability) { nil }
  let(:auth_subject) { nil }
  let(:current_user) { nil }

  subject(:service_response) do
    described_class.execute(
      domain_main_class: domain_main_class,
      domain_main_class_args: domain_main_class_args,
      auth_ability: auth_ability,
      auth_subject: auth_subject,
      current_user: current_user
    )
  end

  describe '#execute' do
    before do
      domain_main_class.send(:response_hash=, response_hash)
      allow(RemoteDevelopment::Settings)
        .to receive(:get).with(RemoteDevelopment::Settings::DefaultSettings.default_settings.keys).and_return(settings)
      allow(RemoteDevelopment::Logger).to receive(:build).and_return(logger)
    end

    context 'when success' do
      let(:payload) { { some_payload: 1 } }
      let(:response_hash) { { status: :success, payload: payload } }

      it "passes settings and logger along with args" do
        expect(settings).to receive(:fetch).with(:some_setting)
        expect(logger).to receive(:debug).with("some log")

        service_response
      end

      it 'returns a success ServiceResponse' do
        expect(service_response).to be_success
        expect(service_response.payload).to eq(payload)
      end

      context "when auth_ability is passed" do
        let(:auth_ability) { :some_ability }

        context "when auth_subject is not nil" do
          let(:auth_subject) { :some_subject }

          context "when current_user is passed" do
            let(:user) { instance_double("User") } # rubocop:disable RSpec/VerifiedDoubleReference -- We're using the quoted version so we can use fast_spec_helper
            let(:current_user) { user }

            before do
              allow(user).to receive(:can?).with(:some_ability, auth_subject).and_return(user_is_authorized)
            end

            context "when user is authorized" do
              let(:user_is_authorized) { true }

              it "does not raise an error" do
                expect { service_response }.not_to raise_error
              end
            end

            context "when user is not authorized" do
              let(:user_is_authorized) { false }

              it "raise an error" do
                expect { service_response }.to raise_error(/User is not authorized/)
              end
            end
          end

          context "when current_user is nil" do
            it "raise an error" do
              expect { service_response }.to raise_error(/current_user is required/)
            end
          end
        end

        context "when auth_subject is nil" do
          let(:auth_subject) { nil }

          it "raise an error" do
            expect { service_response }.to raise_error(/auth_subject is required/)
          end
        end
      end
    end

    context 'when error' do
      context "when main class returns an error response_hash" do
        let(:response_hash) { { status: :error, message: 'error', reason: :bad_request } }

        it 'returns an error success ServiceResponse' do
          expect(service_response).to be_error
          service_response => { message:, reason: }
          expect(message).to eq('error')
          expect(reason).to eq(:bad_request)
        end
      end

      context "when Main class has more than one public singleton method" do
        let(:response_hash) { {} }

        before do
          domain_main_class.define_singleton_method(:foo) do
            nil
          end
        end

        it "raise an error", :unlimited_max_formatted_output_length do
          expect { service_response }.to raise_error(/violation.*exactly one.*public/i)
        end
      end
    end
  end
end
