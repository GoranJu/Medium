# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Namespaces::TrialEligibleFinder, feature_category: :subscription_management do
  describe '#execute', :saas do
    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :gitlab_duo_pro) }
    let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
    let_it_be(:free_plan) { create(:free_plan) }
    let_it_be(:premium_plan) { create(:premium_plan) }

    context 'with no params' do
      subject(:execute) { described_class.new.execute }

      it 'raises an error' do
        expect { execute }.to raise_error(ArgumentError, 'User or Namespace must be provided')
      end
    end

    context 'with namespace' do
      let_it_be(:namespace) { create(:group) }

      before_all do
        create(:group)
      end

      subject { described_class.new(namespace: namespace).execute }

      it { is_expected.to match_array(namespace) }
    end

    context 'with user' do
      let_it_be(:user) { create :user }

      subject(:execute) { described_class.new(user: user).execute }

      context 'when user does not own namespaces' do
        before_all do
          create(:group)
        end

        it { is_expected.to be_empty }
      end

      context 'when user owns namespaces' do
        let_it_be(:regular_namespace) { create(:group, name: 'Zeta', owners: user) }
        let_it_be(:namespace_with_free_plan) { create(:group_with_plan, name: 'Rho', plan: :free_plan, owners: user) }
        let_it_be(:namespace_with_premium_plan) do
          create(:group_with_plan, name: 'Alpha', plan: :premium_plan, owners: user)
        end

        let(:eligible_namespaces) do
          [
            namespace_with_premium_plan,
            namespace_with_free_plan,
            regular_namespace
          ]
        end

        before_all do
          create(:group, parent: regular_namespace)
          create(:group_with_plan, plan: :ultimate_trial_plan, owners: user)
        end

        it { is_expected.to eq(eligible_namespaces) }

        context 'when namespace is provided' do
          subject(:execute) { described_class.new(user: user, namespace: namespace_with_free_plan).execute }

          it 'raises an error' do
            expect { execute }.to raise_error(ArgumentError, 'Only User or Namespace can be provided, not both')
          end
        end

        context 'when a duo enterprise add on exists on a namespace' do
          before do
            create(:gitlab_subscription_add_on_purchase, add_on: duo_enterprise_add_on, namespace: regular_namespace)
          end

          it { is_expected.to eq([namespace_with_premium_plan, namespace_with_free_plan]) }
        end

        context 'when the namespace last trialed as free and is now premium' do
          before_all do
            create(
              :gitlab_subscription_history, :update,
              namespace: namespace_with_premium_plan,
              hosted_plan: free_plan
            )
          end

          context 'and the duo enterprise add on is an expired trial before the namespace changed to premium' do
            before_all do
              create(
                :gitlab_subscription_add_on_purchase, :expired_trial,
                add_on: duo_enterprise_add_on, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq(eligible_namespaces) }

            context 'when a duo pro add on exists on a namespace' do
              context 'and a namespace has an active trial' do
                before do
                  create(
                    :gitlab_subscription_add_on_purchase, :active_trial,
                    add_on: duo_pro_add_on, namespace: namespace_with_premium_plan
                  )
                end

                it { is_expected.to eq([namespace_with_free_plan, regular_namespace]) }
              end

              context 'and a namespace has an active purchase' do
                before do
                  create(
                    :gitlab_subscription_add_on_purchase,
                    add_on: duo_pro_add_on, namespace: namespace_with_premium_plan
                  )
                end

                it { is_expected.to eq(eligible_namespaces) }
              end
            end
          end

          context 'when the duo enterprise add on expired trial after the namespace changed to premium' do
            before do
              create(
                :gitlab_subscription_add_on_purchase, :expired_trial,
                add_on: duo_enterprise_add_on, namespace: namespace_with_premium_plan,
                expires_on: 1.day.from_now
              )
            end

            it { is_expected.to eq([namespace_with_free_plan, regular_namespace]) }
          end
        end

        context 'when the namespace last trialed state was not free' do
          before_all do
            # This is not a real scenario as premium->premium wouldn't trigger an entry in this table,
            # but it's a valid scenario to verify our conditions of only looking for the last free state only.
            create(
              :gitlab_subscription_history, :update,
              namespace: namespace_with_premium_plan,
              hosted_plan: premium_plan
            )
          end

          context 'and the duo enterprise add on is an expired trial before the namespace changed to premium' do
            before_all do
              create(
                :gitlab_subscription_add_on_purchase, :expired_trial,
                add_on: duo_enterprise_add_on, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq([namespace_with_free_plan, regular_namespace]) }
          end
        end

        context 'when a duo pro add on exists on a namespace' do
          before_all do
            create(
              :gitlab_subscription_add_on_purchase, :expired_trial,
              add_on: duo_enterprise_add_on, namespace: namespace_with_premium_plan
            )
          end

          context 'and a namespace has an active purchase' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                add_on: duo_pro_add_on, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq(eligible_namespaces) }
          end

          context 'and a namespace has an expired purchase' do
            before do
              create(
                :gitlab_subscription_add_on_purchase, :expired,
                add_on: duo_pro_add_on, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq(eligible_namespaces) }
          end

          context 'and a namespace has an active trial' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                :active_trial, add_on: duo_pro_add_on, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq([namespace_with_free_plan, regular_namespace]) }
          end

          context 'and a namespace has an expired trial' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                :expired_trial, add_on: duo_pro_add_on, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq(eligible_namespaces) }
          end

          context 'and a namespace has a future active trial' do
            before do
              create(
                :gitlab_subscription_add_on_purchase,
                :future_dated, add_on: duo_pro_add_on, trial: true, namespace: namespace_with_premium_plan
              )
            end

            it { is_expected.to eq(eligible_namespaces) }
          end
        end
      end
    end

    context 'with caching' do
      let_it_be(:user) { create(:user) }
      let_it_be(:namespace_1) { create(:group, owners: user) }
      let_it_be(:namespace_2) { create(:group, owners: user) }

      let(:trials) { ['ultimate_with_gitlab_duo_enterprise'] }
      let(:params) { { use_caching: true } }

      subject(:execute) { described_class.new(params).execute }

      shared_examples 'cached eligible namespaces' do
        let(:cache_key_1) { "namespaces:eligible_trials:#{namespace_1.id}" }
        let(:cache_key_2) { "namespaces:eligible_trials:#{namespace_2.id}" }

        let(:namespaces_response) do
          {
            namespace_1.id.to_s => ['ultimate_with_gitlab_duo_enterprise'],
            namespace_2.id.to_s => %w[ultimate_with_gitlab_duo_enterprise gitlab_duo_pro]
          }
        end

        before do
          allow(Rails.cache).to receive(:exist?).with(cache_key_1).once.and_return(true)
        end

        context 'when cache exists for all namespaces' do
          before do
            allow(Rails.cache).to receive(:exist?).with(cache_key_2).once.and_return(true)

            allow(Rails.cache).to receive(:read_multi).with(cache_key_1, cache_key_2).and_return(
              cache_key_1 => namespaces_response[namespace_1.id.to_s],
              cache_key_2 => namespaces_response[namespace_2.id.to_s]
            )
          end

          it { is_expected.to match_array([namespace_1, namespace_2]) }

          context 'when requested trial is not eligible' do
            let(:trials) { ['premium'] }

            it { is_expected.to eq([]) }
          end
        end

        context 'when cache is not complete' do
          before do
            allow(Rails.cache).to receive(:exist?).with(cache_key_2).once.and_return(false)

            allow(Gitlab::SubscriptionPortal::Client)
              .to receive(:namespace_eligible_trials)
              .with(namespace_ids: [namespace_1.id, namespace_2.id])
              .and_return(response)
          end

          context 'with a successful CustomersDot query', :aggregate_failures do
            let(:response) { { success: true, data: { namespaces: namespaces_response } } }

            it 'caches the query response' do
              expect(Rails.cache).to receive(:write_multi).with(
                {
                  cache_key_1 => namespaces_response[namespace_1.id.to_s],
                  cache_key_2 => namespaces_response[namespace_2.id.to_s]
                },
                expires_in: 8.hours
              )

              expect(execute).to match_array([namespace_1, namespace_2])
            end
          end

          context 'with an unsuccessful CustomersDot query' do
            let(:response) { { success: false } }

            it { is_expected.to eq([]) }
          end
        end
      end

      context 'with no trials params' do
        it 'raises an error' do
          expect { execute }.to raise_error(ArgumentError, 'Trial types must be provided')
        end
      end

      context 'with trials params' do
        let(:params) { super().merge(trials: trials) }

        it 'raises an error' do
          expect { execute }.to raise_error(ArgumentError, 'User or Namespace must be provided')
        end
      end

      context 'with user and namespace' do
        let(:params) { super().merge(user: build(:user), namespace: build(:group), trials: trials) }

        it 'raises an error' do
          expect { execute }.to raise_error(ArgumentError, 'Only User or Namespace can be provided, not both')
        end
      end

      context 'with user' do
        let(:params) { super().merge(user: user, trials: trials) }

        it_behaves_like 'cached eligible namespaces'

        context 'when a user does not own any groups' do
          let(:params) { super().merge(user: build(:user), trials: trials) }

          it { is_expected.to eq([]) }
        end
      end

      context 'with namespaces' do
        let(:params) { super().merge(namespace: [namespace_1, namespace_2], trials: trials) }

        it_behaves_like 'cached eligible namespaces'
      end
    end
  end
end
