# frozen_string_literal: true

RSpec.shared_examples GitlabSubscriptions::Trials::TrialFormComponent do
  let(:eligible_namespaces) { Group.none }
  let(:kwargs) do
    {
      eligible_namespaces: eligible_namespaces,
      params: ActionController::Parameters.new(
        {
          glm_source: 'about.gitlab.com',
          glm_content: 'trial',
          garbage: 'garbage',
          namespace_id: 2,
          new_group_name: 'new group name'
        }
      ),
      namespace_create_errors: 'some error'
    }.merge(additional_kwargs)
  end

  subject(:component) { render_inline(described_class.new(**kwargs)) && page }

  context 'with default content' do
    let(:expected_form_data_attributes) do
      {
        new_group_name: 'new group name',
        initial_value: 2,
        any_trial_eligible_namespaces: 'false',
        items: [
          {
            text: _('New'),
            options: [
              {
                text: _('Create group'),
                value: '0'
              }
            ]
          }
        ].to_json,
        namespace_create_errors: 'some error'
      }
    end

    it { is_expected.to have_content(s_('Trial|Apply your trial to a new group')) }

    it 'has body content' do
      is_expected
        .to have_content(s_('Trials|Create a new group and start your trial of Ultimate with GitLab Duo Enterprise.'))
    end

    it { is_expected.to have_content(_('Activate my trial')) }

    it 'has the correct action attribute' do
      form = component.find('form.js-saas-trial-group')
      expect(form['action']).to eq(trials_path(glm_source: 'about.gitlab.com', glm_content: 'trial', step: 'trial'))
    end

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  describe 'with eligible namespaces' do
    let(:eligible_namespaces) { [build(:group)] }
    let(:expected_form_data_attributes) do
      {
        new_group_name: 'new group name',
        initial_value: 2,
        any_trial_eligible_namespaces: 'true',
        items: [
          {
            text: _('New'),
            options: [
              {
                text: _('Create group'),
                value: '0'
              }
            ]
          },
          {
            text: _('Groups'),
            options: [
              {
                text: eligible_namespaces.first.name,
                value: eligible_namespaces.first.id.to_s
              }
            ]
          }
        ].to_json
      }
    end

    it { is_expected.to have_content(s_('Trial|Apply your trial to a new or existing group')) }

    it 'has body content' do
      is_expected
        .to have_content(s_('Trials|You can apply your trial of Ultimate with GitLab Duo Enterprise to a group.'))
    end

    it { is_expected.to have_content(_('Activate my trial')) }

    it 'renders form with correct attributes' do
      expect_form_data_attribute(expected_form_data_attributes)
    end
  end

  def expect_form_data_attribute(data_attributes)
    data_attributes.each do |attribute, value|
      is_expected.to have_selector(".js-namespace-selector[data-#{attribute.to_s.dasherize}='#{value}']")
    end
  end
end
