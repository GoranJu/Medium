# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Gitlab::Auth::GroupSaml::DuoAddOnAssignmentUpdater, feature_category: :user_management do
  describe '#execute', :sidekiq_inline do
    let_it_be(:user) { create(:user) }
    let_it_be(:group) { create(:group) }
    let(:auth_hash) do
      ::Gitlab::Auth::GroupSaml::AuthHash.new(
        OmniAuth::AuthHash.new(
          extra: {
            raw_info: OneLogin::RubySaml::Attributes.new(groups_info)
          }
        )
      )
    end

    subject(:execute) { described_class.new(user, group, auth_hash).execute }

    shared_examples 'does not call the assignment workers' do
      it 'does not call the workers' do
        expect(::GitlabSubscriptions::AddOnPurchases::CreateUserAddOnAssignmentWorker).not_to receive(:perform_async)
        expect(::GitlabSubscriptions::AddOnPurchases::DestroyUserAddOnAssignmentWorker).not_to receive(:perform_async)

        execute
      end
    end

    context 'when no groups are in the auth hash' do
      let(:groups_info) { {} }

      it_behaves_like 'does not call the assignment workers'
    end

    context 'when groups are in the auth hash' do
      let(:groups_info) { { 'groups' => ['Duo'] } }

      it_behaves_like 'does not call the assignment workers'

      context 'with an active add-on purchase' do
        let_it_be(:add_on_purchase) do
          create(
            :gitlab_subscription_add_on_purchase,
            :gitlab_duo_pro,
            expires_on: 1.week.from_now.to_date,
            namespace: group
          )
        end

        it_behaves_like 'does not call the assignment workers'

        context 'when groups have an associated SAML group link and meet worker conditions' do
          before_all do
            create(:saml_group_link, group: group, saml_group_name: 'Duo', assign_duo_seats: true)
            group.add_developer(user)
          end

          before do
            allow(::Onboarding::CreateIterableTriggerWorker).to receive(:perform_async)
            stub_saas_features(gitlab_duo_saas_only: true)
          end

          it 'assigns one seat' do
            expect { execute }
              .to change {
                user.assigned_add_ons.for_active_add_on_purchase_ids(add_on_purchase.id).count
              }.from(0).to(1)
          end

          context 'when the feature flag is disabled' do
            before do
              stub_feature_flags(saml_groups_duo_add_on_assignment: false)
            end

            it_behaves_like 'does not call the assignment workers'
          end
        end

        context 'when the user is not in a matching SAML group link' do
          before do
            create(:saml_group_link, group: group, saml_group_name: 'Other Group Name', assign_duo_seats: true)
          end

          context 'when an existing assignment already exists' do
            before do
              create(:gitlab_subscription_user_add_on_assignment, user: user, add_on_purchase: add_on_purchase)
            end

            it 'unassigns one seat' do
              expect { execute }
                .to change {
                  user.assigned_add_ons.for_active_add_on_purchase_ids(add_on_purchase.id).count
                }.from(1).to(0)
            end

            context 'when the feature flag is disabled' do
              before do
                stub_feature_flags(saml_groups_duo_add_on_assignment: false)
              end

              it_behaves_like 'does not call the assignment workers'
            end
          end
        end
      end
    end
  end
end
