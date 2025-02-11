# frozen_string_literal: true

require 'spec_helper'

RSpec.describe GitlabSubscriptions::Trials::CreateService, feature_category: :plan_provisioning do
  include TrialHelpers

  let_it_be(:user, reload: true) { create(:user) }
  let_it_be(:organization) { create(:organization, users: [user]) }
  let(:step) { described_class::LEAD }

  describe '#execute', :saas do
    let(:trial_params) { {} }
    let(:extra_lead_params) { {} }
    let(:trial_user_params) do
      { trial_user: lead_params(user, extra_lead_params) }
    end

    let(:lead_service_class) { GitlabSubscriptions::CreateLeadService }
    let(:apply_trial_service_class) { GitlabSubscriptions::Trials::ApplyTrialService }
    let(:add_on_purchase) { build(:gitlab_subscription_add_on_purchase) }

    let_it_be(:duo_pro_add_on) { create(:gitlab_subscription_add_on, :code_suggestions) }
    let_it_be(:duo_enterprise_add_on) { create(:gitlab_subscription_add_on, :duo_enterprise) }

    subject(:execute) do
      described_class.new(
        step: step, lead_params: lead_params(user, extra_lead_params), trial_params: trial_params, user: user
      ).execute
    end

    it_behaves_like 'when on the lead step', :free_plan
    it_behaves_like 'when on trial step', :free_plan
    it_behaves_like 'when on trial step', :premium_plan
    it_behaves_like 'with an unknown step'
    it_behaves_like 'with no step'

    it_behaves_like 'for tracking the lead step', :free_plan, ''
    it_behaves_like 'for tracking the trial step', :free_plan, ''

    context 'with an expired legacy trial' do
      let_it_be(:group) do
        create(:gitlab_subscription, :premium, :expired_trial, :with_group, trial: false).namespace
      end

      let(:step) { described_class::TRIAL }
      let(:namespace_id) { group.id.to_s }
      let(:trial_params) { { namespace_id: namespace_id } }

      before_all do
        group.add_owner(user)
      end

      it 'applies the trial successfully' do
        expect_apply_trial_success(user, group, extra_params: existing_group_attrs(group))

        expect(execute).to be_success
        expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
      end
    end

    context 'with an existing duo enterprise add on' do
      let_it_be(:group) do
        create(:gitlab_subscription_add_on_purchase, add_on: duo_enterprise_add_on).namespace
      end

      let(:step) { described_class::TRIAL }
      let(:namespace_id) { group.id.to_s }
      let(:trial_params) { { namespace_id: namespace_id } }

      before_all do
        group.add_owner(user)
      end

      it 'returns an error for ineligible namespace' do
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'with an active duo pro trial' do
      let_it_be(:group) do
        create(:gitlab_subscription_add_on_purchase, :active_trial, add_on: duo_pro_add_on).namespace
      end

      let(:step) { described_class::TRIAL }
      let(:namespace_id) { group.id.to_s }
      let(:trial_params) { { namespace_id: namespace_id } }

      before_all do
        group.add_owner(user)
      end

      it 'returns an error for ineligible namespace' do
        expect(apply_trial_service_class).not_to receive(:new)

        expect(execute).to be_error
        expect(execute.reason).to eq(:not_found)
      end
    end

    context 'with an expired duo pro trial' do
      let_it_be(:group) do
        create(:gitlab_subscription_add_on_purchase, :expired_trial, add_on: duo_pro_add_on).namespace
      end

      let(:step) { described_class::TRIAL }
      let(:namespace_id) { group.id.to_s }
      let(:trial_params) { { namespace_id: namespace_id } }

      before_all do
        group.add_owner(user)
      end

      it 'applies the trial successfully' do
        expect_apply_trial_success(user, group, extra_params: existing_group_attrs(group))

        expect(execute).to be_success
        expect(execute.payload).to eq({ namespace: group, add_on_purchase: add_on_purchase })
      end
    end

    context 'when in the create group flow' do
      let(:step) { described_class::TRIAL }
      let(:extra_params) { { organization_id: organization.id, with_add_on: true, add_on_name: "duo_enterprise" } }

      let(:trial_params) do
        { new_group_name: 'gitlab', namespace_id: '0' }.merge(extra_params)
      end

      context 'when group is successfully created' do
        context 'when trial creation is successful' do
          it 'return success with the namespace' do
            allow(::Namespace.sticking).to receive(:stick).with(anything, anything).and_call_original

            expect_next_instance_of(apply_trial_service_class) do |instance|
              expect(instance).to receive(:execute).and_return(
                ServiceResponse.success(payload: { add_on_purchase: add_on_purchase })
              )
            end

            expect { execute }.to change { Group.count }.by(1)

            expect(::Namespace.sticking).to have_received(:stick).with(:namespace, Group.last.id)
            expect(execute).to be_success
            expect(execute.payload).to eq({ namespace: Group.last, add_on_purchase: add_on_purchase })
          end
        end

        context 'when trial creation fails' do
          it 'returns an error indicating trial failed' do
            stub_apply_trial(
              user, namespace_id: anything, success: false, extra_params: extra_params.merge(new_group_attrs)
            )

            expect { execute }.to change { Group.count }.by(1)

            expect(execute).to be_error
            expect(execute.payload).to eq({ namespace_id: Group.last.id })
          end
        end

        context 'when group name needs sanitized' do
          it 'return success with the namespace path sanitized for duplication' do
            create(:group_with_plan, plan: :free_plan, name: 'gitlab')

            stub_apply_trial(
              user, namespace_id: anything, success: true,
              extra_params: extra_params.merge(new_group_attrs(path: 'gitlab1'))
            )

            expect { execute }.to change { Group.count }.by(1)

            expect(execute).to be_success
            expect(execute.payload[:namespace].path).to eq('gitlab1')
          end
        end
      end

      context 'when user is not allowed to create groups' do
        before do
          user.can_create_group = false
        end

        it 'returns not_found' do
          expect(apply_trial_service_class).not_to receive(:new)

          expect { execute }.not_to change { Group.count }
          expect(execute).to be_error
          expect(execute.reason).to eq(:not_found)
        end
      end

      context 'when group creation had an error' do
        context 'when there are invalid characters used' do
          let(:trial_params) { { new_group_name: ' _invalid_ ', namespace_id: '0', organization_id: organization.id } }

          it 'returns namespace_create_failed' do
            expect(apply_trial_service_class).not_to receive(:new)

            expect { execute }.not_to change { Group.count }
            expect(execute).to be_error
            expect(execute.reason).to eq(:namespace_create_failed)
            expect(execute.message.to_sentence).to match(/^Group URL can only include non-accented letters/)
            expect(execute.payload[:namespace_id]).to eq('0')
          end
        end

        context 'when name is entered with blank spaces' do
          let(:trial_params) { { new_group_name: '  ', namespace_id: '0', organization_id: organization.id } }

          it 'returns namespace_create_failed' do
            expect(apply_trial_service_class).not_to receive(:new)

            expect { execute }.not_to change { Group.count }
            expect(execute).to be_error
            expect(execute.reason).to eq(:namespace_create_failed)
            expect(execute.message.to_sentence).to match(/^Name can't be blank/)
            expect(execute.payload[:namespace_id]).to eq('0')
          end
        end
      end
    end

    context 'when lead was submitted with an intended namespace' do
      let(:trial_params) { { namespace_id: non_existing_record_id.to_s } }

      it 'does not create a trial and returns that there is no namespace' do
        stub_lead_without_trial(trial_user_params)

        expect_to_trigger_trial_step(execute, extra_lead_params, trial_params)
      end
    end
  end

  def lead_params(user, extra_lead_params)
    {
      company_name: 'GitLab',
      company_size: '1-99',
      first_name: user.first_name,
      last_name: user.last_name,
      phone_number: '+1 23 456-78-90',
      country: 'US',
      work_email: user.email,
      uid: user.id,
      setup_for_company: user.setup_for_company,
      skip_email_confirmation: true,
      gitlab_com_trial: true,
      provider: 'gitlab',
      state: 'CA'
    }.merge(extra_lead_params)
  end
end
