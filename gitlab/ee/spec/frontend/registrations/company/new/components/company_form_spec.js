import { GlButton, GlForm } from '@gitlab/ui';
import CompanyForm from 'ee/registrations/components/company_form.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { trackCompanyForm } from 'ee/google_tag_manager';

const SUBMIT_PATH = '_submit_path_';

jest.mock('ee/google_tag_manager');

describe('CompanyForm', () => {
  let wrapper;

  const createComponent = (provideData = {}) => {
    return shallowMountExtended(CompanyForm, {
      provide: {
        submitPath: SUBMIT_PATH,
        user: {
          firstName: 'Joe',
          lastName: 'Doe',
          emailDomain: '_email_domain_',
        },
        trackActionForErrors: '_trackActionForErrors_',
        formType: 'registration',
        ...provideData,
      },
    });
  };

  const findDescription = () => wrapper.findByTestId('description');
  const findSubmitButton = () => wrapper.findComponent(GlButton);
  const findForm = () => wrapper.findComponent(GlForm);
  const findFormInput = (testId) => wrapper.findByTestId(testId);
  const findFooterDescriptionText = () => wrapper.findByTestId('footer_description_text');

  describe('rendering', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it.each`
      testid
      ${'first_name'}
      ${'last_name'}
      ${'company_name'}
      ${'company_size'}
      ${'country'}
      ${'phone_number'}
      ${'website_url'}
    `('has the correct form input in the form content', ({ testid }) => {
      expect(findFormInput(testid).exists()).toBe(true);
    });
  });

  describe('when formType is trial', () => {
    beforeEach(() => {
      wrapper = createComponent({ formType: 'trial' });
    });

    it('displays correct description text', () => {
      expect(findDescription().text()).toBe(
        'To activate your trial, we need additional details from you.',
      );
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Continue');
    });

    it('does not display footer text', () => {
      expect(findFooterDescriptionText().text()).toBe('');
    });
  });

  describe('when formType is registration', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('displays correct description text', () => {
      expect(findDescription().text()).toBe(
        'To complete registration, we need additional details from you.',
      );
    });

    it('displays correct text on submit button', () => {
      expect(findSubmitButton().text()).toBe('Start free Ultimate + GitLab Duo Enterprise trial');
    });

    it('displays correct footer text', () => {
      expect(findFooterDescriptionText().exists()).toBe(true);
      expect(findFooterDescriptionText().text()).toBe(
        'Your free Ultimate & GitLab Duo Enterprise Trial lasts for 60 days. After this period, you can maintain a GitLab Free account forever, or upgrade to a paid plan.',
      );
    });
  });

  describe('submitting', () => {
    beforeEach(() => {
      wrapper = createComponent();
    });

    it('submits the form when button is clicked', () => {
      expect(findSubmitButton().attributes('type')).toBe('submit');
    });

    it('displays form with correct action', () => {
      expect(findForm().attributes('action')).toBe(SUBMIT_PATH);
    });

    it('tracks form submission', () => {
      findForm().vm.$emit('submit');

      expect(trackCompanyForm).toHaveBeenCalledWith('ultimate_trial', '_email_domain_');
    });
  });
});
