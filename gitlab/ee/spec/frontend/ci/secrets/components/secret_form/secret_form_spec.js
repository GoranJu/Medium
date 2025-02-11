import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlCollapsibleListbox, GlDatepicker, GlFormInput, GlFormTextarea } from '@gitlab/ui';
import { createAlert } from '~/alert';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { getDateInFuture } from '~/lib/utils/datetime_utility';
import { shallowMountExtended, mountExtended } from 'helpers/vue_test_utils_helper';
import CiEnvironmentsDropdown from '~/ci/common/private/ci_environments_dropdown';
import SecretForm from 'ee/ci/secrets/components/secret_form/secret_form.vue';
import SecretBranchesField from 'ee/ci/secrets/components/secret_form/secret_branches_field.vue';
import CreateSecretMutation from 'ee/ci/secrets/graphql/mutations/create_secret.mutation.graphql';
import GetProjectBranches from 'ee/ci/secrets/graphql/queries/get_project_branches.query.graphql';
import { DETAILS_ROUTE_NAME } from 'ee/ci/secrets/constants';
import { mockProjectBranches, mockProjectSecret } from '../../mock_data';

jest.mock('~/alert');
Vue.use(VueApollo);

describe('SecretForm component', () => {
  let wrapper;
  let mockApollo;
  let mockCreateSecretResponse;
  let mockProjectBranchesResponse;
  const mockRouter = {
    push: jest.fn(),
    currentRoute: {},
  };

  const defaultProps = {
    areEnvironmentsLoading: false,
    environments: ['production', 'development'],
    fullPath: 'path/to/project',
    isEditing: false,
    submitButtonText: 'Add secret',
  };

  const findAddCronButton = () => wrapper.findByTestId('add-custom-rotation-button');
  const findCronField = () => wrapper.findByTestId('secret-cron');
  const findBranchField = () => wrapper.findComponent(SecretBranchesField);
  const findDescriptionField = () => wrapper.findByTestId('secret-description');
  const findDescriptionFieldGroup = () => wrapper.findByTestId('secret-description-field-group');
  const findExpirationField = () => wrapper.findComponent(GlDatepicker);
  const findEnvironmentsDropdown = () => wrapper.findComponent(CiEnvironmentsDropdown);
  const findNameFieldGroup = () => wrapper.findByTestId('secret-name-field-group');
  const findNameField = () => findNameFieldGroup().findComponent(GlFormInput);
  const findRotationPeriodField = () => wrapper.findComponent(GlCollapsibleListbox);
  const findValueFieldGroup = () => wrapper.findByTestId('secret-value-field-group');
  const findValueField = () => findValueFieldGroup().findComponent(GlFormTextarea);
  const findSubmitButton = () => wrapper.findByTestId('submit-form-button');

  const createComponent = ({ props, mountFn = shallowMountExtended, stubs } = {}) => {
    const handlers = [
      [CreateSecretMutation, mockCreateSecretResponse],
      [GetProjectBranches, mockProjectBranchesResponse],
    ];

    mockApollo = createMockApollo(handlers);

    wrapper = mountFn(SecretForm, {
      apolloProvider: mockApollo,
      mocks: {
        $router: mockRouter,
      },
      propsData: {
        ...defaultProps,
        ...props,
      },
      stubs,
    });
  };

  const today = new Date();
  const expirationDate = getDateInFuture(today, 1);

  const inputExpiration = () => {
    findExpirationField().vm.$emit('input', { endDate: '' });
    findExpirationField().vm.$emit('input', expirationDate);
  };

  const inputRequiredFields = async () => {
    findNameField().vm.$emit('input', 'SECRET_KEY');
    findValueField().vm.$emit('input', 'SECRET_VALUE');
    findBranchField().vm.$emit('select-branch', 'main');
    findEnvironmentsDropdown().vm.$emit('select-environment', '*');

    await nextTick();

    inputExpiration();
  };

  const submitSecret = async () => {
    await inputRequiredFields();

    findSubmitButton().vm.$emit('click');
  };

  beforeEach(() => {
    mockCreateSecretResponse = jest.fn();
    mockProjectBranchesResponse = jest.fn().mockResolvedValue(mockProjectBranches);
  });

  afterEach(() => {
    createAlert.mockClear();
  });

  describe('template', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders all fields', () => {
      expect(findBranchField().exists()).toBe(true);
      expect(findDescriptionField().exists()).toBe(true);
      expect(findExpirationField().exists()).toBe(true);
      expect(findEnvironmentsDropdown().exists()).toBe(true);
      expect(findNameField().exists()).toBe(true);
      expect(findRotationPeriodField().exists()).toBe(true);
      expect(findValueField().exists()).toBe(true);
    });

    it('sets expiration date in the future', () => {
      const expirationMinDate = findExpirationField().props('minDate').getTime();
      expect(expirationMinDate).toBeGreaterThan(today.getTime());
    });
  });

  describe('environment dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { CiEnvironmentsDropdown } });
    });

    it('sets the environment', async () => {
      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('');

      findEnvironmentsDropdown().vm.$emit('select-environment', 'staging');
      await nextTick();

      expect(findEnvironmentsDropdown().props('selectedEnvironmentScope')).toBe('staging');
    });

    it('does not require environment (shows Not Applicable option)', () => {
      expect(findEnvironmentsDropdown().props('isEnvironmentRequired')).toBe(false);
    });

    it('bubbles up the search event', async () => {
      findEnvironmentsDropdown().vm.$emit('search-environment-scope', 'dev');
      await nextTick();

      expect(wrapper.emitted('search-environment')).toEqual([['dev']]);
    });
  });

  describe('branch dropdown', () => {
    beforeEach(() => {
      createComponent({ stubs: { SecretBranchesField } });
    });

    it('sets the branch', async () => {
      expect(findBranchField().props('selectedBranch')).toBe('');

      findBranchField().vm.$emit('select-branch', 'main');
      await nextTick();

      expect(findBranchField().props('selectedBranch')).toBe('main');
    });
  });

  describe('rotation period field', () => {
    beforeEach(() => {
      createComponent();
    });

    it('shows default toggle text', () => {
      expect(findRotationPeriodField().props('toggleText')).toBe('Select a reminder interval');
    });

    it('can select predefined rotation periods and renders the correct toggle text', async () => {
      findRotationPeriodField().vm.$emit('click');
      findRotationPeriodField().vm.$emit('select', '14');

      await nextTick();

      expect(findRotationPeriodField().props('toggleText')).toBe('Every 2 weeks');
    });

    it('can set custom cron', async () => {
      findRotationPeriodField().vm.$emit('click');
      findCronField().vm.$emit('input', '0 6 * * *');
      findAddCronButton().vm.$emit('click');

      await nextTick();

      expect(findRotationPeriodField().props('toggleText')).toBe('0 6 * * *');
    });
  });

  describe('form validation', () => {
    beforeEach(() => {
      createComponent();
    });

    it('validates name field', async () => {
      expect(findNameField().attributes('state')).toBe('true');

      findNameField().vm.$emit('input', '');
      await nextTick();

      expect(findNameField().attributes('state')).toBeUndefined();
      expect(findNameFieldGroup().attributes('invalid-feedback')).toBe('This field is required');

      findNameField().vm.$emit('input', 'SECRET_KEY');
      await nextTick();

      expect(findNameField().attributes('state')).toBe('true');
    });

    it('validates value field', async () => {
      expect(findValueField().attributes('state')).toBe('true');

      findValueField().vm.$emit('input', '');
      await nextTick();

      expect(findValueField().attributes('state')).toBeUndefined();
      expect(findValueFieldGroup().attributes('invalid-feedback')).toBe('This field is required');

      findValueField().vm.$emit('input', 'SECRET_VALUE');
      await nextTick();

      expect(findValueField().attributes('state')).toBe('true');
    });

    it('validates description field', async () => {
      expect(findDescriptionField().attributes('state')).toBe('true');

      // string must be <= SECRET_DESCRIPTION_MAX_LENGTH (200) characters
      findDescriptionField().vm.$emit(
        'input',
        'Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.',
      );
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBeUndefined();
      expect(findDescriptionFieldGroup().attributes('invalid-feedback')).toBe(
        'Description must be 200 characters or less.',
      );

      findDescriptionField().vm.$emit('input', 'This is a short description of the secret.');
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBe('true');

      // description can be empty
      findDescriptionField().vm.$emit('input', '');
      await nextTick();

      expect(findDescriptionField().attributes('state')).toBe('true');
    });

    it('submit button is enabled when required fields have input', async () => {
      expect(findSubmitButton().props('disabled')).toBe(true);

      await inputRequiredFields();
      await nextTick();

      expect(findSubmitButton().props('disabled')).toBe(false);
    });
  });

  describe('form submission', () => {
    beforeEach(() => {
      createComponent({ mountFn: mountExtended });
    });

    it('while submitting', async () => {
      expect(findSubmitButton().props('loading')).toBe(false);

      await submitSecret();
      await nextTick();

      expect(findSubmitButton().props('loading')).toBe(true);
    });

    describe('when submission is successful', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(mockProjectSecret());
        createComponent({ mountFn: mountExtended });
      });

      it('redirects to the secret details page', async () => {
        await submitSecret();
        await waitForPromises();

        expect(mockRouter.push).toHaveBeenCalledWith({
          name: DETAILS_ROUTE_NAME,
          params: { secretName: 'SECRET_KEY' },
        });
      });
    });

    describe('when submission returns errors', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockResolvedValue(
          mockProjectSecret({ errors: ['This secret is invalid.'] }),
        );
        createComponent({ mountFn: mountExtended });
      });

      it('renders error message from API', async () => {
        await submitSecret();
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({ message: 'This secret is invalid.' });
      });
    });

    describe('when submission fails', () => {
      beforeEach(() => {
        mockCreateSecretResponse.mockRejectedValue(new Error());
        createComponent({ mountFn: mountExtended });
      });

      it('renders error message from API', async () => {
        await submitSecret();
        await waitForPromises();

        expect(findSubmitButton().props('loading')).toBe(false);
        expect(createAlert).toHaveBeenCalledWith({
          message: 'Something went wrong on our end. Please try again.',
        });
      });
    });
  });
});
