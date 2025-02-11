# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::LeadFormComponent do
  let(:user) { build(:user) }
  let(:eligible_namespaces) { Group.none }
  let(:submit_path) { '/trial/new' }
  let(:namespace_id) { nil }
  let(:kwargs) do
    {
      user: user,
      namespace_id: namespace_id,
      eligible_namespaces: eligible_namespaces,
      submit_path: submit_path
    }.merge(additional_kwargs)
  end

  subject { render_inline(described_class.new(**kwargs)) && page }

  shared_examples 'displays default trial header' do
    it { is_expected.to have_content('Start your free Ultimate and GitLab Duo Enterprise trial') }
  end

  context 'with default content' do
    let(:expected_form_data_attributes) do
      {
        first_name: user.first_name,
        last_name: user.last_name,
        email_domain: user.email_domain,
        company_name: user.organization,
        submit_button_text: 'Continue',
        submit_path: submit_path
      }
    end

    it_behaves_like 'displays default trial header'

    it { is_expected.to have_content(s_('Trial|Please provide the following information to start your trial.')) }

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  context 'with namespace_id' do
    let(:group) { build_stubbed(:group) }
    let(:namespace_id) { group.id }

    context 'when the group is eligible' do
      let(:eligible_namespaces) { [group] }

      before do
        allow(eligible_namespaces).to receive(:find_by_id).with(namespace_id).and_return(group)
      end

      it { is_expected.to have_content("Start your free Ultimate and GitLab Duo Enterprise trial on #{group.name}") }
    end

    context 'when the group is not eligible' do
      it_behaves_like 'displays default trial header'
    end
  end

  describe 'with eligible namespaces' do
    context 'when single namespace' do
      let(:group) { build_stubbed(:group) }
      let(:eligible_namespaces) { [group] }

      it { is_expected.to have_content("Start your free Ultimate and GitLab Duo Enterprise trial on #{group.name}") }

      it 'shows activate trial button' do
        expect_form_data_attribute(submit_button_text: 'Activate my trial')
      end
    end

    context 'when multiple namespaces' do
      let(:eligible_namespaces) { build_list(:group, 2) }

      it_behaves_like 'displays default trial header'
    end
  end

  def expect_form_data_attribute(data_attributes)
    data_attributes.each do |attribute, value|
      is_expected.to have_selector("#js-trial-create-lead-form[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
