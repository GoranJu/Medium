import { nextTick } from 'vue';
import { GlButton, GlModal } from '@gitlab/ui';
import { SEAT_CONTROL } from 'ee/pages/admin/application_settings/general/constants';
import SeatControlSection from 'ee_component/pages/admin/application_settings/general/components/seat_control_section.vue';
import { stubComponent } from 'helpers/stub_component';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { mockData } from 'jest/admin/signup_restrictions/mock_data';
import SignupForm from '~/pages/admin/application_settings/general/components/signup_form.vue';

describe('SignUpRestrictionsApp', () => {
  /** @type {import('helpers/vue_test_utils_helper').ExtendedWrapper} */
  let wrapper;
  let formSubmitSpy;

  const findForm = () => wrapper.findByTestId('form');
  const findModal = () => wrapper.findComponent(GlModal);
  const findSeatControlSection = () => wrapper.findComponent(SeatControlSection);
  const findAutoApprovePendingUsersField = () =>
    wrapper.find('[name="application_setting[auto_approve_pending_users]"]');
  const findFormSubmitButton = () => findForm().findComponent(GlButton);

  const mountComponent = ({ injectedProps = {} } = {}) => {
    wrapper = mountExtended(SignupForm, {
      provide: {
        glFeatures: { passwordComplexity: true, seatControl: true },
        ...mockData,
        ...injectedProps,
      },
      stubs: {
        SignupCheckbox: true,
      },
    });
  };

  afterEach(() => {
    formSubmitSpy = null;
  });

  describe('form data', () => {
    beforeEach(() => {
      mountComponent({
        injectedProps: {
          canDisableMemberPromotionManagement: false,
          rolePromotionRequestsPath: '',
        },
      });
    });

    it.each`
      prop                                 | propValue                                   | elementSelector                                                       | formElementPassedDataType | formElementKey | expected
      ${'passwordNumberRequired'}          | ${mockData.passwordNumberRequired}          | ${'[name="application_setting[password_number_required]"]'}           | ${'prop'}                 | ${'value'}     | ${mockData.passwordNumberRequired}
      ${'passwordLowercaseRequired'}       | ${mockData.passwordLowercaseRequired}       | ${'[name="application_setting[password_lowercase_required]"]'}        | ${'prop'}                 | ${'value'}     | ${mockData.passwordLowercaseRequired}
      ${'passwordUppercaseRequired'}       | ${mockData.passwordUppercaseRequired}       | ${'[name="application_setting[password_uppercase_required]"]'}        | ${'prop'}                 | ${'value'}     | ${mockData.passwordUppercaseRequired}
      ${'passwordSymbolRequired'}          | ${mockData.passwordSymbolRequired}          | ${'[name="application_setting[password_symbol_required]"]'}           | ${'prop'}                 | ${'value'}     | ${mockData.passwordSymbolRequired}
      ${'enableMemberPromotionManagement'} | ${mockData.enableMemberPromotionManagement} | ${'[name="application_setting[enable_member_promotion_management]"]'} | ${'prop'}                 | ${'value'}     | ${mockData.enableMemberPromotionManagement}
    `(
      'form element $elementSelector gets $expected value for $formElementKey $formElementPassedDataType when prop $prop is set to $propValue',
      ({ elementSelector, expected, formElementKey, formElementPassedDataType }) => {
        const formElement = wrapper.find(elementSelector);

        switch (formElementPassedDataType) {
          case 'attribute':
            expect(formElement.attributes(formElementKey)).toBe(expected);
            break;
          case 'prop':
            expect(formElement.props(formElementKey)).toBe(expected);
            break;
          case 'value':
            expect(formElement.element.value).toBe(expected);
            break;
          default:
            expect(formElement.props(formElementKey)).toBe(expected);
            break;
        }
      },
    );
  });

  describe('form submit button confirmation modal for side-effect of adding possibly unwanted new users', () => {
    describe('modal actions', () => {
      beforeEach(() => {
        const INITIAL_USER_CAP = 5;
        const INITIAL_SEAT_CONTROL = SEAT_CONTROL.USER_CAP;

        mountComponent({
          injectedProps: {
            newUserSignupsCap: INITIAL_USER_CAP,
            seatControl: INITIAL_SEAT_CONTROL,
            pendingUserCount: 5,
          },
          stubs: { GlButton, GlModal: stubComponent(GlModal) },
        });

        findSeatControlSection().vm.$emit('checkUsersAutoApproval', true);

        findFormSubmitButton().trigger('click');

        return nextTick();
      });

      describe('clicking approve users button', () => {
        beforeEach(() => {
          formSubmitSpy = jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation();

          findModal().vm.$emit('primary');

          return nextTick();
        });

        it('submits the form', () => {
          expect(formSubmitSpy).toHaveBeenCalled();
        });

        it('submits the form with the correct value', () => {
          expect(findAutoApprovePendingUsersField().attributes('value')).toBe('true');
        });
      });

      describe('clicking proceed without approve button', () => {
        beforeEach(() => {
          formSubmitSpy = jest.spyOn(HTMLFormElement.prototype, 'submit').mockImplementation();

          findModal().vm.$emit('secondary');

          return nextTick();
        });

        it('submits the form', () => {
          expect(formSubmitSpy).toHaveBeenCalled();
        });

        it('submits the form with the correct value', () => {
          expect(findAutoApprovePendingUsersField().attributes('value')).toBe('false');
        });
      });
    });
  });
});
