import { GlCollapsibleListbox, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import DenyAllowExceptions from 'ee/security_orchestration/components/policy_editor/scan_result/rule/deny_allow_list_exceptions.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { EXCEPTION_KEY } from 'ee/security_orchestration/components/policy_editor/constants';

describe('DenyAllowExceptions', () => {
  let wrapper;

  const VALID_EXCEPTIONS_STRING = 'test@project, test1@project';
  const EXCEPTIONS_WITHOUT_FULL_PATH_STRING = 'test@project, test1';
  const EXCEPTIONS_WITH_DUPLICATES_STRING = 'test@project, test@project, test2@project';

  const VALID_EXCEPTIONS = ['test@project', 'test1@project'];

  const INVALID_EXCEPTIONS = ['project', 'project1'];

  const createComponent = ({ propsData } = {}) => {
    wrapper = shallowMountExtended(DenyAllowExceptions, {
      propsData,
      stubs: {
        GlSprintf,
      },
    });
  };

  const findListBox = () => wrapper.findComponent(GlCollapsibleListbox);
  const findTextArea = () => wrapper.findComponent(GlFormTextarea);
  const findDuplicateErrorMessage = () => wrapper.findByTestId('error-duplicates-message');
  const findValidationErrorMessage = () => wrapper.findByTestId('error-validation-message');
  const findFormatDescription = () => wrapper.findByTestId('format-description');

  describe('default rendering', () => {
    it('renders default list with no exceptions', () => {
      createComponent();

      expect(findListBox().props('toggleText')).toBe('No exceptions');
      expect(findTextArea().exists()).toBe(false);
    });

    it('selects exception type', () => {
      createComponent();

      findListBox().vm.$emit('select', EXCEPTION_KEY);

      expect(wrapper.emitted('select-exception-type')).toEqual([[EXCEPTION_KEY]]);
    });

    it('renders selected license', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      expect(findListBox().props('selected')).toBe(EXCEPTION_KEY);
      expect(findListBox().props('toggleText')).toBe('Exceptions');
    });

    it('disables type dropdown', () => {
      createComponent({
        propsData: {
          disabled: true,
        },
      });

      expect(findListBox().props('disabled')).toBe(true);
    });
  });

  describe('selected exceptions', () => {
    it('renders selected exceptions as string', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
          exceptions: VALID_EXCEPTIONS,
        },
      });

      expect(findTextArea().props('value')).toBe(VALID_EXCEPTIONS_STRING);
      expect(findFormatDescription().text()).toBe(
        'Use purl format for package paths: scheme:type/namespace/name@version?qualifiers#subpath. For multiple packages, separate paths with comma ",".',
      );
    });

    it('selects exceptions', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      findTextArea().vm.$emit('input', VALID_EXCEPTIONS_STRING);

      expect(findDuplicateErrorMessage().exists()).toBe(false);
      expect(findValidationErrorMessage().exists()).toBe(false);
      expect(wrapper.emitted('input')).toEqual([[VALID_EXCEPTIONS]]);
    });
  });

  describe('error state', () => {
    it('renders validation error state when invalid exceptions passed by default', () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
          exceptions: INVALID_EXCEPTIONS,
        },
      });

      expect(findDuplicateErrorMessage().exists()).toBe(false);
      expect(findValidationErrorMessage().text()).toBe(
        'Add project full path after @ to following exceptions: project project1',
      );
    });

    it('renders duplicate error', async () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      await findTextArea().vm.$emit('input', EXCEPTIONS_WITH_DUPLICATES_STRING);

      expect(findValidationErrorMessage().exists()).toBe(false);
      expect(findDuplicateErrorMessage().text()).toBe('Duplicates will be removed');
    });

    it('renders validation error', async () => {
      createComponent({
        propsData: {
          exceptionType: EXCEPTION_KEY,
        },
      });

      await findTextArea().vm.$emit('input', EXCEPTIONS_WITHOUT_FULL_PATH_STRING);

      expect(findDuplicateErrorMessage().exists()).toBe(false);
      expect(findValidationErrorMessage().text()).toBe(
        'Add project full path after @ to following exceptions: test1',
      );
    });
  });
});
