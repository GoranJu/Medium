# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Search::Zoekt::NodeBackoff, :clean_gitlab_redis_cache, feature_category: :global_search do
  subject(:backoff) { described_class.new(node, max_backoff: max_backoff) }

  let(:node) { create(:zoekt_node) }
  let(:key) { backoff.backoff_cache_key }
  let(:max_backoff) { 30.minutes }

  describe '.enabled?' do
    it 'is true whenever a backoff is set' do
      expect { backoff.backoff! }.to change { backoff.enabled? }.from(false).to(true)
      expect { backoff.backoff! }.not_to change { backoff.enabled? }
    end

    it 'resets after backoff expiry' do
      backoff.backoff!
      expect(backoff).to be_enabled
      ::Gitlab::Redis::SharedState.with { |redis| redis.del(key) }
      expect(backoff).to receive(:reload!).and_call_original
      expect(backoff).not_to be_enabled
    end
  end

  describe '.num_failures' do
    it 'is incremented whenever a backoff occurs' do
      expect { backoff.backoff! }.to change { backoff.num_failures }.from(0).to(1)
      expect { backoff.backoff! }.to change { backoff.num_failures }.from(1).to(2)
    end

    it 'resets after backoff expiry' do
      backoff.backoff!
      expect(backoff.num_failures).to eq(1)
      ::Gitlab::Redis::SharedState.with { |redis| redis.del(key) }
      backoff.reload!
      expect(backoff.num_failures).to eq(0)
    end
  end

  describe '.backoff!' do
    it 'increments number of failures in redis and sets expiry correctly', :freeze_time do
      fake_redis = instance_double(::Redis)

      allow(backoff).to receive(:expires_in_s).and_return(max_backoff)
      allow(::Gitlab::Redis::SharedState).to receive(:with).and_yield(fake_redis)
      allow(fake_redis).to receive(:multi).and_yield(fake_redis)
      allow(fake_redis).to receive(:get).with(key).and_return(0)

      expect(fake_redis).to receive(:incr).with(key)
      expect(fake_redis).to receive(:expireat).with(key, max_backoff.from_now.to_i)

      backoff.backoff!
    end
  end

  describe '.expires_in_s' do
    it 'uses exponential backoff depending on number of failures' do
      random_milliseconds = 0.2

      10.times do |n|
        num_failures = n + 1
        allow(backoff).to receive(:num_failures).and_return(num_failures)
        allow(backoff).to receive(:rand).with(0.001..1).and_return(random_milliseconds)

        expected_backoff_time_s = ((2**num_failures) + random_milliseconds).seconds

        expect(backoff.expires_in_s).to eq(expected_backoff_time_s)
      end
    end

    it 'has a maximum backoff time' do
      allow(backoff).to receive(:num_failures).and_return(1_000_000)
      expect(backoff.expires_in_s).to eq(backoff.max_backoff)
    end
  end

  describe '.expires_at', :freeze_time do
    it 'is set for a new backoff' do
      expect(backoff.expires_at).not_to be_nil
    end

    it 'is expiration date time' do
      expect(backoff).to receive(:expires_in_s).twice.and_return(5.seconds)
      backoff.backoff!
      expect(backoff.expires_at).to eq(5.seconds.from_now)
    end
  end

  describe '.seconds_remaining', :freeze_time do
    it 'is number of seconds until expiration' do
      expect(backoff).to receive(:expires_in_s).twice.and_return(5.seconds)
      backoff.backoff!
      expect(backoff.seconds_remaining).to eq(5.seconds)
    end
  end

  describe '.remove_backoff!' do
    it 'disables the backoff' do
      backoff.backoff!
      expect { backoff.remove_backoff! }.to change { backoff.enabled? }.from(true).to(false)
    end

    it 'resets the number of failures' do
      backoff.backoff!
      expect { backoff.remove_backoff! }.to change { backoff.num_failures }.from(1).to(0)
    end
  end
end
