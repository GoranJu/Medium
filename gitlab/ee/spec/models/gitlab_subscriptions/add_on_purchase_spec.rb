# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::AddOnPurchase, feature_category: :plan_provisioning do
  subject { build(:gitlab_subscription_add_on_purchase) }

  it { is_expected.to include_module(EachBatch) }

  describe 'constants' do
    it { expect(described_class::CLEANUP_DELAY_PERIOD).to be_a(ActiveSupport::Duration) }
  end

  describe 'associations' do
    it { is_expected.to belong_to(:add_on).with_foreign_key(:subscription_add_on_id).inverse_of(:add_on_purchases) }
    it { is_expected.to belong_to(:namespace).optional(true) }
    it { is_expected.to belong_to(:organization) }

    it do
      is_expected.to have_many(:assigned_users)
        .class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:add_on_purchase)
    end

    it do
      is_expected.to have_many(:assigned_users)
        .dependent(:destroy).class_name('GitlabSubscriptions::UserAddOnAssignment').inverse_of(:add_on_purchase)
    end
  end

  describe 'validations' do
    it { is_expected.to validate_presence_of(:add_on) }
    it { is_expected.to validate_presence_of(:expires_on) }
    it { is_expected.to validate_presence_of(:started_at) }

    context 'when validating namespace' do
      context 'when on .com', :saas do
        before do
          stub_ee_application_setting(should_check_namespace_plan: true)
        end

        using RSpec::Parameterized::TableSyntax

        let_it_be(:group_namespace) { create(:group) }
        let_it_be(:sub_group_namespace) { create(:group, parent: group_namespace) }
        let_it_be(:project_namespace) { create(:project_namespace) }
        let_it_be(:user_namespace) { create(:user_namespace) }

        where(:namespace, :result) do
          ref(:group_namespace)     | true
          ref(:sub_group_namespace) | false
          ref(:project_namespace)   | false
          ref(:user_namespace)      | false
          nil                       | false
        end

        with_them do
          it 'validates the namespace correctly' do
            record = build(:gitlab_subscription_add_on_purchase, namespace: namespace)

            expect(record.valid?).to eq(result)
            expect(record.errors.of_kind?(:namespace, :invalid)).to eq(!result)
          end
        end
      end

      context 'when not on .com' do
        it { is_expected.not_to validate_presence_of(:namespace) }
      end
    end

    it { is_expected.to validate_uniqueness_of(:subscription_add_on_id).scoped_to(:namespace_id) }
    it { is_expected.to validate_presence_of(:quantity) }
    it { is_expected.to validate_numericality_of(:quantity).only_integer.is_greater_than_or_equal_to(1) }

    it { is_expected.to validate_presence_of(:purchase_xid) }
    it { is_expected.to validate_length_of(:purchase_xid).is_at_most(255) }
  end

  describe 'scopes' do
    shared_context 'with add-on purchases' do
      let_it_be(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on) }
      let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      let_it_be(:expired_gitlab_duo_pro_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, :expired, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, started_at: Date.current)
      end

      let_it_be(:expired_gitlab_duo_pro_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, expires_on: Date.current)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:future_dated_gitlab_duo_pro_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, :future_dated, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:active_gitlab_duo_pro_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on)
      end

      let_it_be(:expired_product_analytics_purchase_as_owner) do
        create(:gitlab_subscription_add_on_purchase, :expired, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_as_guest) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on, started_at: Date.current)
      end

      let_it_be(:expired_product_analytics_purchase_as_reporter) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on, expires_on: Date.current)
      end

      let_it_be(:active_product_analytics_purchase_as_developer) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:future_dated_product_analytics_purchase_as_maintainer) do
        create(:gitlab_subscription_add_on_purchase, :future_dated, add_on: product_analytics_add_on)
      end

      let_it_be(:active_product_analytics_purchase_unrelated) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:user) { create(:user) }

      before do
        expired_gitlab_duo_pro_purchase_as_owner.namespace.add_owner(user)
        active_gitlab_duo_pro_purchase_as_guest.namespace.add_guest(user)
        expired_gitlab_duo_pro_purchase_as_reporter.namespace.add_reporter(user)
        active_gitlab_duo_pro_purchase_as_developer.namespace.add_developer(user)
        future_dated_gitlab_duo_pro_purchase_as_maintainer.namespace.add_maintainer(user)

        expired_product_analytics_purchase_as_owner.namespace.add_owner(user)
        active_product_analytics_purchase_as_guest.namespace.add_guest(user)
        expired_product_analytics_purchase_as_reporter.namespace.add_reporter(user)
        active_product_analytics_purchase_as_developer.namespace.add_developer(user)
        future_dated_product_analytics_purchase_as_maintainer.namespace.add_maintainer(user)
      end
    end

    describe '.active' do
      subject(:active_purchases) { described_class.active }

      include_context 'with add-on purchases'

      it 'returns all the purchases that are not expired' do
        expect(active_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_guest,
            active_gitlab_duo_pro_purchase_as_developer,
            active_gitlab_duo_pro_purchase_unrelated,
            active_product_analytics_purchase_as_guest,
            active_product_analytics_purchase_as_developer,
            active_product_analytics_purchase_unrelated
          ]
        )
      end
    end

    describe '.ready_for_cleanup' do
      let(:add_on) { create(:gitlab_subscription_add_on) }
      let(:active_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          expires_on: Date.current
        )
      end

      let(:ready_for_clean_up_add_on_purchase) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: add_on,
          expires_on: (described_class::CLEANUP_DELAY_PERIOD + 1.day).ago.to_date
        )
      end

      before do
        active_add_on_purchase
        ready_for_clean_up_add_on_purchase
      end

      it 'returns all ready for cleanup add on purchases' do
        expect(described_class.ready_for_cleanup).to match_array(ready_for_clean_up_add_on_purchase)
      end
    end

    describe '.trial' do
      include_context 'with add-on purchases'

      let_it_be(:gitlab_duo_pro_purchase_trial) do
        create(:gitlab_subscription_add_on_purchase, :trial, add_on: gitlab_duo_pro_add_on)
      end

      subject(:trials) { described_class.trial }

      it 'returns all the purchases that are not expired' do
        expect(trials).to match_array([gitlab_duo_pro_purchase_trial])
      end
    end

    describe '.by_add_on_name' do
      subject(:by_name_purchases) { described_class.by_add_on_name(name) }

      include_context 'with add-on purchases'

      context 'when name is: code_suggestions' do
        let(:name) { 'code_suggestions' }

        it 'returns all the purchases related to gitlab_duo_pro' do
          expect(by_name_purchases).to match_array(
            [
              expired_gitlab_duo_pro_purchase_as_owner,
              active_gitlab_duo_pro_purchase_as_guest,
              expired_gitlab_duo_pro_purchase_as_reporter,
              active_gitlab_duo_pro_purchase_as_developer,
              future_dated_gitlab_duo_pro_purchase_as_maintainer,
              active_gitlab_duo_pro_purchase_unrelated
            ]
          )
        end
      end

      context 'when name is set to anything else' do
        let(:name) { 'foo-bar' }

        it 'returns empty collection' do
          expect(by_name_purchases).to eq([])
        end
      end
    end

    describe '.by_namespace' do
      subject(:result) { described_class.by_namespace(namespace_id) }

      include_context 'with add-on purchases'

      context 'when record with given namespace_id exists' do
        let(:namespace_id) { active_gitlab_duo_pro_purchase_as_developer.namespace_id }

        it { is_expected.to contain_exactly(active_gitlab_duo_pro_purchase_as_developer) }

        context 'when namespace record is passed' do
          subject { described_class.by_namespace(active_gitlab_duo_pro_purchase_as_developer.namespace) }

          it { is_expected.to contain_exactly(active_gitlab_duo_pro_purchase_as_developer) }
        end
      end

      context 'when record with given namespace_id does not exist' do
        let(:namespace_id) { non_existing_record_id }

        it { is_expected.to match_array([]) }
      end

      context 'when nil is given' do
        let(:namespace_id) { nil }

        context 'and the record exist' do
          let(:add_on_purchase_with_namespace_id_nil) do
            create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, namespace_id: nil)
          end

          it { is_expected.to contain_exactly(add_on_purchase_with_namespace_id_nil) }
        end

        context 'and the record does not exist' do
          it { is_expected.to match_array([]) }
        end
      end
    end

    describe '.for_self_managed' do
      include_context 'with add-on purchases'

      let!(:self_managed_purchase) do
        create(:gitlab_subscription_add_on_purchase, add_on: gitlab_duo_pro_add_on, namespace: nil)
      end

      subject(:self_managed_purchases) { described_class.for_self_managed }

      it 'returns only add-on purchases without a namespace' do
        expect(self_managed_purchases).to contain_exactly(self_managed_purchase)
      end
    end

    describe '.for_gitlab_duo_pro' do
      subject(:gitlab_duo_pro_purchases) { described_class.for_gitlab_duo_pro }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to gitlab duo' do
        expect(gitlab_duo_pro_purchases).to match_array(
          [
            expired_gitlab_duo_pro_purchase_as_owner,
            active_gitlab_duo_pro_purchase_as_guest,
            expired_gitlab_duo_pro_purchase_as_reporter,
            active_gitlab_duo_pro_purchase_as_developer,
            future_dated_gitlab_duo_pro_purchase_as_maintainer,
            active_gitlab_duo_pro_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_product_analytics' do
      subject(:product_analytics_purchases) { described_class.for_product_analytics }

      include_context 'with add-on purchases'

      it 'returns all the purchases related to product_analytics' do
        expect(product_analytics_purchases).to match_array(
          [
            expired_product_analytics_purchase_as_owner,
            active_product_analytics_purchase_as_guest,
            expired_product_analytics_purchase_as_reporter,
            active_product_analytics_purchase_as_developer,
            future_dated_product_analytics_purchase_as_maintainer,
            active_product_analytics_purchase_unrelated
          ]
        )
      end
    end

    describe '.for_duo_enterprise' do
      subject(:duo_enterprise_add_on_purchases) { described_class.for_duo_enterprise }

      it { expect(duo_enterprise_add_on_purchases).to be_empty }

      context 'with duo_enterprise purchase' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }

        it { expect(duo_enterprise_add_on_purchases).to eq [duo_enterprise_add_on] }
      end

      context 'with other purchases' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
        let!(:code_suggestions_add_on) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro) }

        it 'returns only duo_enterprise add-ons' do
          expect(duo_enterprise_add_on_purchases).to eq [duo_enterprise_add_on]
        end
      end
    end

    describe '.for_duo_pro_or_duo_enterprise' do
      subject(:duo_pro_or_duo_enterprise_add_on_purchases) { described_class.for_duo_pro_or_duo_enterprise }

      it { expect(duo_pro_or_duo_enterprise_add_on_purchases).to be_empty }

      context 'with duo_enterprise purchase' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }

        it { expect(duo_pro_or_duo_enterprise_add_on_purchases).to eq [duo_enterprise_add_on] }
      end

      context 'with duo_pro purchase' do
        let!(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro) }

        it { expect(duo_pro_or_duo_enterprise_add_on_purchases).to eq [gitlab_duo_pro_add_on] }
      end

      context 'with other purchases' do
        let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
        let!(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro) }
        let!(:product_analytics_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }

        it 'returns both gitlab_duo_pro and duo_enterprise add-ons' do
          expect(duo_pro_or_duo_enterprise_add_on_purchases).to match_array(
            [duo_enterprise_add_on, gitlab_duo_pro_add_on]
          )
        end
      end
    end

    describe '.for_duo_add_ons' do
      subject(:duo_add_ons_purchases) { described_class.for_duo_add_ons }

      let!(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on_purchase, :duo_enterprise) }
      let!(:gitlab_duo_pro_add_on) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro) }
      let!(:product_analytics_add_on) { create(:gitlab_subscription_add_on_purchase, :product_analytics) }

      it 'returns both gitlab_duo_pro and duo_enterprise add-ons' do
        expect(duo_add_ons_purchases).to contain_exactly(
          duo_enterprise_add_on, gitlab_duo_pro_add_on
        )
      end
    end

    describe '.for_user', :saas do
      subject(:user_purchases) { described_class.for_user(user) }

      include_context 'with add-on purchases'

      it 'returns all the non-guest purchases related to the user top level namespaces' do
        expect(user_purchases).to match_array(
          [
            expired_gitlab_duo_pro_purchase_as_owner,
            expired_gitlab_duo_pro_purchase_as_reporter,
            active_gitlab_duo_pro_purchase_as_developer,
            future_dated_gitlab_duo_pro_purchase_as_maintainer,
            expired_product_analytics_purchase_as_owner,
            expired_product_analytics_purchase_as_reporter,
            active_product_analytics_purchase_as_developer,
            future_dated_product_analytics_purchase_as_maintainer
          ]
        )
      end
    end

    describe '.assigned_to_user', :saas do
      before do
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_as_guest
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: active_gitlab_duo_pro_purchase_as_developer
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: future_dated_gitlab_duo_pro_purchase_as_maintainer
        )
        create(
          :gitlab_subscription_user_add_on_assignment,
          user: user,
          add_on_purchase: expired_gitlab_duo_pro_purchase_as_owner
        )
      end

      subject(:user_purchases) { described_class.assigned_to_user(user) }

      include_context 'with add-on purchases'

      it 'returns all active purchases related to the user add-on assignments' do
        expect(user_purchases).to match_array(
          [
            active_gitlab_duo_pro_purchase_as_guest,
            active_gitlab_duo_pro_purchase_as_developer
          ]
        )
      end
    end

    describe '.requiring_assigned_users_refresh' do
      let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
      let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }
      let_it_be(:product_analytics_add_on) { create(:gitlab_subscription_add_on, :product_analytics) }

      let_it_be(:duo_pro_add_on_purchase_fresh) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: duo_pro_add_on,
          last_assigned_users_refreshed_at: 1.hour.ago
        )
      end

      let_it_be(:duo_enterprise_add_on_purchase_fresh) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: duo_enterprise_add_on,
          last_assigned_users_refreshed_at: 1.hour.ago
        )
      end

      let_it_be(:duo_pro_add_on_purchase_refreshed_nil) do
        create(:gitlab_subscription_add_on_purchase, add_on: duo_pro_add_on)
      end

      let_it_be(:duo_enterprise_add_on_purchase_refreshed_nil) do
        create(:gitlab_subscription_add_on_purchase, add_on: duo_enterprise_add_on)
      end

      let_it_be(:product_analytics_add_on_purchase_refreshed_nil) do
        create(:gitlab_subscription_add_on_purchase, add_on: product_analytics_add_on)
      end

      let_it_be(:duo_pro_add_on_purchase_stale) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: duo_pro_add_on,
          last_assigned_users_refreshed_at: 21.hours.ago
        )
      end

      let_it_be(:duo_enterprise_add_on_purchase_stale) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: duo_enterprise_add_on,
          last_assigned_users_refreshed_at: 21.hours.ago
        )
      end

      let_it_be(:product_analytics_add_on_purchase_stale) do
        create(
          :gitlab_subscription_add_on_purchase,
          add_on: product_analytics_add_on,
          last_assigned_users_refreshed_at: 21.hours.ago
        )
      end

      it 'returns correct add_on_purchases' do
        query_limit = 5
        result = [
          duo_pro_add_on_purchase_refreshed_nil,
          duo_enterprise_add_on_purchase_refreshed_nil,
          duo_pro_add_on_purchase_stale,
          duo_enterprise_add_on_purchase_stale
        ]

        expect(described_class.requiring_assigned_users_refresh(query_limit))
          .to match_array(result)
      end

      it 'accepts limit param' do
        query_limit = 1

        expect(described_class.requiring_assigned_users_refresh(query_limit).size).to eq 1
      end
    end

    describe '.find_by_namespace_and_add_on' do
      subject(:find_by_namespace_and_add_on) { described_class.find_by_namespace_and_add_on }

      let(:namespace) { create(:group) }

      let(:add_on_1) { create(:gitlab_subscription_add_on, :code_suggestions) }
      let(:add_on_2) { create(:gitlab_subscription_add_on, :product_analytics) }

      let!(:add_on_purchase_1) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_1) }
      let!(:add_on_purchase_2) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on_1) }

      let!(:add_on_purchase_3) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_2) }
      let!(:add_on_purchase_4) { create(:gitlab_subscription_add_on_purchase, namespace: namespace, add_on: add_on_2) }

      it 'filters by namespace and add-on' do
        expect(described_class.find_by_namespace_and_add_on(nil, add_on_1)).to eq add_on_purchase_1
        expect(described_class.find_by_namespace_and_add_on(namespace, add_on_1)).to eq add_on_purchase_2
      end
    end
  end

  describe 'delegations' do
    it { is_expected.to delegate_method(:name).to(:add_on).with_prefix.allow_nil }
  end

  describe '.uniq_add_on_names' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }

    before do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on)
      create(:gitlab_subscription_add_on_purchase, add_on: add_on)
    end

    subject(:add_on_names) { described_class.uniq_add_on_names }

    it { is_expected.to match_array('code_suggestions') }
  end

  describe '.uniq_namespace_ids' do
    let(:namespace_1) { create(:group) }
    let(:namespace_2) { create(:group) }

    let(:add_on_1) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let(:add_on_2) { create(:gitlab_subscription_add_on, :product_analytics) }

    let!(:add_on_purchase_1) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_1) }
    let!(:add_on_purchase_2) { create(:gitlab_subscription_add_on_purchase, namespace: namespace_1, add_on: add_on_1) }

    let!(:add_on_purchase_3) { create(:gitlab_subscription_add_on_purchase, namespace: nil, add_on: add_on_2) }
    let!(:add_on_purchase_4) { create(:gitlab_subscription_add_on_purchase, namespace: namespace_1, add_on: add_on_2) }

    let!(:add_on_purchase_5) { create(:gitlab_subscription_add_on_purchase, namespace: namespace_2, add_on: add_on_2) }

    subject(:namespace_ids) { described_class.uniq_namespace_ids }

    it { is_expected.to match_array([namespace_1.id, namespace_2.id]) }
  end

  describe '.next_candidate_requiring_assigned_users_refresh' do
    let_it_be(:add_on) { create(:gitlab_subscription_add_on) }
    let_it_be(:add_on_purchase_fresh) do
      create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.hour.ago)
    end

    subject(:next_candidate) { described_class.next_candidate_requiring_assigned_users_refresh }

    context 'when there are stale records' do
      let_it_be(:add_on_purchase_stale) do
        create(:gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 21.hours.ago)
      end

      it 'returns the stale record' do
        expect(next_candidate).to eq(add_on_purchase_stale)
      end

      context 'when there is stale records with nil refreshed_at' do
        it 'returns record with nil refreshed_at as next candidate' do
          result = create(:gitlab_subscription_add_on_purchase, add_on: add_on)

          expect(next_candidate).to eq(result)
        end
      end

      context 'when there is stale record with earlier refreshed_at' do
        it 'returns record with earlier refreshed_at as next candidate' do
          result = create(
            :gitlab_subscription_add_on_purchase, add_on: add_on, last_assigned_users_refreshed_at: 1.day.ago
          )

          expect(next_candidate).to eq(result)
        end
      end
    end

    it 'returns nil when there are no stale records' do
      expect(next_candidate).to eq(nil)
    end
  end

  describe '.maximum_duo_seat_count' do
    shared_examples 'seat count calculation' do
      subject(:seat_count) { described_class.maximum_duo_seat_count(namespace_ids: namespace_ids) }

      context 'when there is no duo add-on' do
        let(:expected_maximum_duo_seat_count) { 0 }

        it 'returns the default of 0' do
          expect(seat_count).to eq(expected_maximum_duo_seat_count)
        end
      end

      context 'when there is a duo pro add-on' do
        let(:expected_maximum_duo_seat_count) { 10 }

        it 'returns the number of seats purchased' do
          create(:gitlab_subscription_add_on_purchase, :active, :gitlab_duo_pro,
            options.merge(quantity: expected_maximum_duo_seat_count))

          expect(seat_count).to eq(expected_maximum_duo_seat_count)
        end
      end

      context 'when there is a duo enterprise add-on' do
        let(:expected_maximum_duo_seat_count) { 20 }

        it 'returns the number of seats purchased' do
          create(:gitlab_subscription_add_on_purchase, :active, :duo_enterprise,
            options.merge(quantity: expected_maximum_duo_seat_count))

          expect(seat_count).to eq(expected_maximum_duo_seat_count)
        end
      end

      context 'when there is both a duo pro add-on and a duo enterprise trial add-on' do
        let(:expected_duo_enterprise_seat_count) { 15 }
        let(:expected_duo_pro_seat_count) { 5 }

        it 'returns the maximum number of seats purchased for the add-on with the most seats' do
          create(:gitlab_subscription_add_on_purchase, :active, :duo_enterprise, :trial,
            options.merge(quantity: expected_duo_enterprise_seat_count))
          create(:gitlab_subscription_add_on_purchase, :active, :gitlab_duo_pro,
            options.merge(quantity: expected_duo_pro_seat_count))

          expect(seat_count).to eq(expected_duo_enterprise_seat_count)
        end
      end

      context 'when there is both a duo pro trial add-on and a duo enterprise add-on' do
        let(:expected_duo_enterprise_seat_count) { 10 }
        let(:expected_duo_pro_seat_count) { 40 }

        it 'returns the maximum number of seats purchased for the add-on with the most seats' do
          create(:gitlab_subscription_add_on_purchase, :active, :duo_enterprise,
            options.merge(quantity: expected_duo_enterprise_seat_count))
          create(:gitlab_subscription_add_on_purchase, :active, :gitlab_duo_pro, :trial,
            options.merge(quantity: expected_duo_pro_seat_count))

          expect(seat_count).to eq(expected_duo_pro_seat_count)
        end
      end
    end

    context 'when no namespace IDs are given' do
      let(:namespace_ids) { [] }
      let(:options) { { namespace: nil } }

      include_examples 'seat count calculation'
    end

    context 'when namespace IDs are given' do
      let_it_be(:group) { create(:group) }

      let(:namespace_ids) { [group.id] }
      let(:options) { { namespace: group } }

      include_examples 'seat count calculation'

      context 'with more than one group namespace' do
        let_it_be(:other_group) { create(:group) }

        it 'returns the highest seat count of both' do
          create(:gitlab_subscription_add_on_purchase, :active, :duo_enterprise,
            quantity: 20, namespace: group)
          create(:gitlab_subscription_add_on_purchase, :active, :gitlab_duo_pro,
            quantity: 10, namespace: other_group)

          expect(described_class.maximum_duo_seat_count(namespace_ids: [group.id, other_group.id])).to eq(20)
        end
      end
    end
  end

  describe '#already_assigned?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    let(:user) { create(:user) }

    subject { add_on_purchase.already_assigned?(user) }

    context 'when the user has been already assigned' do
      before do
        create(:gitlab_subscription_user_add_on_assignment, add_on_purchase: add_on_purchase, user: user)
      end

      it { is_expected.to eq(true) }
    end

    context 'when user is not already assigned' do
      it { is_expected.to eq(false) }
    end
  end

  describe '#active?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.active? }

    it { is_expected.to eq(true) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to eq(false) } }
    end
  end

  describe '#expired?' do
    let_it_be(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    subject { add_on_purchase.expired? }

    it { is_expected.to eq(false) }

    context 'when subscription has expired' do
      it { travel_to(add_on_purchase.expires_on + 1.day) { is_expected.to eq(true) } }
    end
  end

  describe '#delete_ineligible_user_assignments_in_batches!' do
    let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase, :gitlab_duo_pro) }

    let_it_be(:eligible_user) { create(:user) }
    let_it_be(:ineligible_user) { create(:user) }

    let(:expected_log) do
      {
        message: 'Ineligible UserAddOnAssignments destroyed',
        user_ids: [ineligible_user.id],
        add_on: 'code_suggestions',
        add_on_purchase: add_on_purchase.id,
        namespace: add_on_purchase.namespace.path
      }
    end

    subject(:result) { add_on_purchase.delete_ineligible_user_assignments_in_batches! }

    context 'with assigned_users records' do
      before do
        add_on_purchase.assigned_users.create!(user: eligible_user)
        add_on_purchase.assigned_users.create!(user: ineligible_user)
      end

      it 'does not log' do
        expect(Gitlab::AppLogger).not_to receive(:info).with(expected_log)

        result
      end

      context 'with ineligible user' do
        before do
          add_on_purchase.namespace.add_guest(eligible_user)
        end

        it 'removes only ineligible user assignments' do
          expect(add_on_purchase.reload.assigned_users.count).to eq(2)

          expect do
            expect(result).to eq(1)
          end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

          expect(add_on_purchase.reload.assigned_users.where(user: eligible_user).count).to eq(1)
        end

        it 'logs deleted user add-on assignements' do
          expect(Gitlab::AppLogger).to receive(:info).with(expected_log)

          result
        end
      end

      it 'accepts batch_size and deletes the assignments in batch' do
        expect(GitlabSubscriptions::UserAddOnAssignment).to receive(:pluck_user_ids).twice.and_call_original

        result = add_on_purchase.delete_ineligible_user_assignments_in_batches!(batch_size: 1)

        expect(result).to eq(2)
      end

      it 'expires the cache keys for the ineligible users', :use_clean_rails_redis_caching do
        eligible_user_cache_key = eligible_user.duo_pro_cache_key_formatted
        ineligible_user_cache_key = ineligible_user.duo_pro_cache_key_formatted
        Rails.cache.write(eligible_user_cache_key, true, expires_in: 1.hour)
        Rails.cache.write(ineligible_user_cache_key, true, expires_in: 1.hour)

        add_on_purchase.namespace.add_guest(eligible_user)

        expect(add_on_purchase.reload.assigned_users.count).to eq(2)

        expect { expect(result).to eq(1) }
          .to change { add_on_purchase.reload.assigned_users.count }.by(-1)
          .and change { Rails.cache.read(ineligible_user_cache_key) }.from(true).to(nil)
          .and not_change { Rails.cache.read(eligible_user_cache_key) }
      end

      context 'when the add_on_purchase has no namespace' do
        before do
          add_on_purchase.update_attribute(:namespace, nil)
        end

        context 'when all assigned users are eligible' do
          it { is_expected.to eq(0) }
        end

        context 'when there are ineligible users' do
          it 'removes only ineligible user assignments' do
            ineligible_user.block!

            expect(add_on_purchase.reload.assigned_users.count).to eq(2)

            expect_next_instance_of(::GitlabSubscriptions::SelfManaged::AddOnEligibleUsersFinder) do |finder|
              expect(finder).to receive(:execute).and_call_original
            end

            expect do
              expect(result).to eq(1)
            end.to change { add_on_purchase.reload.assigned_users.count }.by(-1)

            expect(add_on_purchase.reload.assigned_users.where(user: eligible_user).count).to eq(1)
          end
        end
      end
    end

    context 'with no assigned_users records' do
      it { is_expected.to eq(0) }

      context 'when add_on_purchase does not have namespace' do
        before do
          add_on_purchase.update!(namespace: nil)
        end

        it { is_expected.to eq(0) }
      end
    end
  end

  describe "#lock_key_for_refreshing_user_assignments" do
    let(:add_on_purchase) { create(:gitlab_subscription_add_on_purchase) }

    it 'returns lock key based on class name and id' do
      lock_key = "gitlab_subscriptions/add_on_purchase:user_refresh:#{add_on_purchase.id}"

      expect(add_on_purchase.lock_key_for_refreshing_user_assignments).to eq(lock_key)
    end
  end

  describe '#destroy' do
    it_behaves_like 'create audits for user add-on assignments' do
      let(:entity) { add_on_purchase }
    end
  end
end
