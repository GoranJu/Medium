# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::ClickHouse, feature_category: :database do
  describe '.enabled_for_analytics?' do
    context 'when ClickHouse is configured' do
      before do
        allow(described_class).to receive(:configured?).and_return(true)
      end

      it { is_expected.not_to be_enabled_for_analytics }

      context 'and enabled for analytics on settings' do
        before do
          stub_application_setting(use_clickhouse_for_analytics: true)
        end

        it { is_expected.to be_enabled_for_analytics }
      end
    end

    context 'when ClickHouse is not configured' do
      before do
        allow(described_class).to receive(:configured?).and_return(false)
      end

      it { is_expected.not_to be_enabled_for_analytics }

      context 'and is enabled for analytics on settings' do
        before do
          stub_application_setting(use_clickhouse_for_analytics: true)
        end

        it { is_expected.not_to be_enabled_for_analytics }
      end
    end
  end
end
