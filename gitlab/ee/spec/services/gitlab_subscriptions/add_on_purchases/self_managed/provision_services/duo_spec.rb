# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchases::SelfManaged::ProvisionServices::Duo,
  :aggregate_failures, feature_category: :'add-on_provisioning' do
  describe '#execute', :aggregate_failures do
    subject(:provision_service) { described_class.new }

    let_it_be(:add_on_duo_pro) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let_it_be(:add_on_duo_enterprise) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    let_it_be(:organization) { create(:organization) }

    let(:quantity_duo_pro) { 0 }
    let(:quantity_duo_enterprise) { 0 }
    let(:namespace) { nil }

    let(:started_at) { Date.current }
    let!(:current_license) do
      create_current_license(
        cloud_licensing_enabled: true,
        restrictions: {
          add_on_products: add_on_products(started_at: started_at),
          subscription_name: 'A-S00000001'
        }
      )
    end

    context 'without Duo' do
      let!(:current_license) do
        create_current_license(
          cloud_licensing_enabled: true,
          restrictions: {
            add_on_products: {},
            subscription_name: 'A-S00000001'
          }
        )
      end

      it 'does not create a Duo Pro add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)
      end
    end

    context 'with Duo Pro' do
      let(:quantity_duo_pro) { 1 }

      context 'with a trial' do
        let!(:current_license) do
          create_current_license(
            cloud_licensing_enabled: true,
            restrictions: {
              add_on_products: add_on_products(started_at: started_at, trial: true),
              subscription_name: 'A-S00000001'
            }
          )
        end

        it 'creates a new Duo Pro add-on purchase' do
          expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

          expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            subscription_add_on_id: add_on_duo_pro.id,
            quantity: quantity_duo_pro,
            started_at: started_at,
            expires_on: started_at + 1.year,
            purchase_xid: 'duo_pro_purchase',
            trial: true
          )
        end
      end

      it 'creates a new Duo Pro add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_pro.id,
          quantity: quantity_duo_pro,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: 'duo_pro_purchase',
          trial: false
        )
      end
    end

    context 'with existing Duo Pro and seat count increase' do
      let!(:add_on_purchase_duo_pro) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_pro,
          quantity: 1,
          namespace: namespace
        )
      end

      let(:quantity_duo_pro) { 2 }

      context 'with a trial' do
        let!(:current_license) do
          create_current_license(
            cloud_licensing_enabled: true,
            restrictions: {
              add_on_products: add_on_products(started_at: started_at, trial: true),
              subscription_name: 'A-S00000001'
            }
          )
        end

        it 'updates quantity of existing add-on purchase' do
          expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

          expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
          expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
            subscription_add_on_id: add_on_duo_pro.id,
            quantity: quantity_duo_pro,
            started_at: started_at,
            expires_on: started_at + 1.year,
            purchase_xid: 'duo_pro_purchase',
            trial: true
          )
        end
      end

      it 'updates quantity of existing add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_pro.id,
          quantity: quantity_duo_pro,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: 'duo_pro_purchase',
          trial: false
        )
      end
    end

    context 'with existing Duo Pro and additional purchase of Duo Enterprise' do
      let!(:add_on_purchase_duo_pro) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_pro,
          quantity: quantity_duo_pro,
          namespace: namespace
        )
      end

      let(:quantity_duo_enterprise) { 1 }
      let(:quantity_duo_pro) { 1 }

      it 'upgrade to Duo Enterprise' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_enterprise.id,
          quantity: quantity_duo_enterprise,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: 'duo_enterprise_purchase',
          trial: false
        )
      end
    end

    context 'with Duo Enterprise' do
      let(:quantity_duo_enterprise) { 1 }

      it 'creates a new Duo Enterprise add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(1)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_enterprise.id,
          quantity: quantity_duo_enterprise,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: 'duo_enterprise_purchase',
          trial: false
        )
      end
    end

    context 'with existing Duo Enterprise and seat count increase' do
      let!(:add_on_purchase_duo_enterprise) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_enterprise,
          quantity: 1,
          namespace: namespace
        )
      end

      let(:quantity_duo_enterprise) { 2 }

      it 'updates quantity of existing add-on purchase' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_enterprise.id,
          quantity: quantity_duo_enterprise,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: 'duo_enterprise_purchase',
          trial: false
        )
      end
    end

    context 'with existing Duo Enterprise and downgrade to Duo Pro' do
      let!(:add_on_purchase_duo_enterprise) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on_duo_enterprise,
          quantity: 1,
          namespace: namespace
        )
      end

      let(:quantity_duo_enterprise) { 0 }
      let(:quantity_duo_pro) { 1 }

      it 'downgrades to Duo Pro' do
        expect { provision_service.execute }.to change { GitlabSubscriptions::AddOnPurchase.count }.by(0)

        expect(GitlabSubscriptions::AddOnPurchase.count).to eq(1)
        expect(GitlabSubscriptions::AddOnPurchase.first).to have_attributes(
          subscription_add_on_id: add_on_duo_pro.id,
          quantity: quantity_duo_pro,
          started_at: started_at,
          expires_on: started_at + 1.year,
          purchase_xid: 'duo_pro_purchase',
          trial: false
        )
      end
    end
  end

  private

  def add_on_products(started_at:, trial: false)
    [:duo_pro, :duo_enterprise].each_with_object({}) do |add_on_name, products|
      quantity = send(:"quantity_#{add_on_name}")
      next products if quantity <= 0

      products[add_on_name] = [
        {
          "quantity" => quantity,
          "started_on" => started_at.to_s,
          "expires_on" => (started_at + 1.year).to_s,
          "purchase_xid" => "#{add_on_name}_purchase",
          "trial" => trial
        }
      ]
    end
  end
end
