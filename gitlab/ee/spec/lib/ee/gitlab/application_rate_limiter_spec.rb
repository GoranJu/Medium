# frozen_string_literal: true

require 'spec_helper'

RSpec.describe EE::Gitlab::ApplicationRateLimiter do
  describe '.rate_limits' do
    subject(:rate_limits) { Gitlab::ApplicationRateLimiter.rate_limits }

    context 'when application-level rate limits are configured' do
      before do
        stub_application_setting(max_number_of_repository_downloads: 1)
        stub_application_setting(max_number_of_repository_downloads_within_time_period: 60)
        stub_application_setting(soft_phone_verification_transactions_daily_limit: 60)
        stub_application_setting(hard_phone_verification_transactions_daily_limit: 100)
      end

      it 'includes values for unique_project_downloads_for_application', :aggregate_failures do
        values = rate_limits[:unique_project_downloads_for_application]
        expect(values[:threshold].call).to eq 1
        expect(values[:interval].call).to eq 60
      end

      it 'includes values for code_suggestions_api_endpoint' do
        values = rate_limits[:code_suggestions_api_endpoint]
        expect(values).to eq(threshold: 60, interval: 1.minute)
      end

      it 'includes values for code_suggestions_direct_access' do
        values = rate_limits[:code_suggestions_direct_access]
        expect(values).to eq(threshold: 50, interval: 1.minute)
      end

      it 'includes values for code_suggestions_x_ray_scan' do
        values = rate_limits[:code_suggestions_x_ray_scan]
        expect(values).to eq(threshold: 60, interval: 1.minute)
      end

      it 'includes values for code_suggestions_x_ray_dependencies' do
        values = rate_limits[:code_suggestions_x_ray_dependencies]
        expect(values).to eq(threshold: 60, interval: 1.minute)
      end

      it 'includes values for duo_workflow_direct_access' do
        values = rate_limits[:duo_workflow_direct_access]
        expect(values).to eq(threshold: 50, interval: 1.minute)
      end

      it 'includes values for soft_phone_verification_transactions_daily_limit' do
        values = rate_limits[:soft_phone_verification_transactions_limit]
        expect(values).to eq(threshold: 60, interval: 1.day)
      end

      it 'includes values for hard_phone_verification_transactions_daily_limit' do
        values = rate_limits[:hard_phone_verification_transactions_limit]
        expect(values).to eq(threshold: 100, interval: 1.day)
      end
    end

    context 'when namespace-level rate limits are configured' do
      it 'includes fixed default values for unique_project_downloads_for_namespace', :aggregate_failures do
        values = rate_limits[:unique_project_downloads_for_namespace]
        expect(values[:threshold]).to eq 0
        expect(values[:interval]).to eq 0
      end

      it 'includes fixed default values for soft_phone_verification_transactions_limit' do
        values = rate_limits[:soft_phone_verification_transactions_limit]
        expect(values).to eq(threshold: 16000, interval: 1.day)
      end

      it 'includes fixed default values for hard_phone_verification_transactions_limit' do
        values = rate_limits[:hard_phone_verification_transactions_limit]
        expect(values).to eq(threshold: 20000, interval: 1.day)
      end
    end
  end
end
