import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { GlModal, GlButton, GlSprintf, GlDisclosureDropdownItem } from '@gitlab/ui';
import { shallowMount, createWrapper } from '@vue/test-utils';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { BV_SHOW_MODAL } from '~/lib/utils/constants';
import { createAlert } from '~/alert';
import deleteSelfHostedModelMutation from 'ee/pages/admin/ai/self_hosted_models/graphql/mutations/delete_self_hosted_model.mutation.graphql';
import getSelfHostedModelsQuery from 'ee/pages/admin/ai/self_hosted_models/graphql/queries/get_self_hosted_models.query.graphql';
import DeleteSelfHostedModelDisclosureItem from 'ee/pages/admin/ai/self_hosted_models/components/delete_self_hosted_model_disclosure_item.vue';
import { mockSelfHostedModelsList } from './mock_data';

Vue.use(VueApollo);

jest.mock('~/alert');
jest.mock('~/lib/utils/url_utility');

describe('DeleteSelfHostedModelDisclosureItem', () => {
  let wrapper;

  const modelWithFeatureSettings = mockSelfHostedModelsList[0];
  const modelWithoutFeatureSettings = mockSelfHostedModelsList[1];

  const deleteMutationSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModelDelete: {
        errors: [],
      },
    },
  });

  const getSelfHostedModelsSuccessHandler = jest.fn().mockResolvedValue({
    data: {
      aiSelfHostedModels: {
        errors: [],
      },
    },
  });

  const createComponent = ({
    apolloHandlers = [[deleteSelfHostedModelMutation, deleteMutationSuccessHandler]],
    props = {},
  } = {}) => {
    const mockApollo = createMockApollo([
      [getSelfHostedModelsQuery, getSelfHostedModelsSuccessHandler],
      ...apolloHandlers,
    ]);

    wrapper = extendedWrapper(
      shallowMount(DeleteSelfHostedModelDisclosureItem, {
        apolloProvider: mockApollo,
        propsData: {
          model: modelWithoutFeatureSettings,
          ...props,
        },
        stubs: { GlModal, GlButton, GlSprintf },
      }),
    );
  };

  const findModal = () => wrapper.findComponent(GlModal);
  const findDisclosureDeleteButton = () => wrapper.findComponent(GlDisclosureDropdownItem);
  const findModalText = () => wrapper.findByTestId('delete-model-confirmation-message').text();
  const findSecondaryButton = () => wrapper.findAllComponents(GlButton).at(0);
  const findDeleteButton = () => wrapper.findAllComponents(GlButton).at(1);

  it('renders the disclosure delete button', () => {
    createComponent();

    expect(findDisclosureDeleteButton().text()).toBe('Delete');
  });

  it('renders the modal', () => {
    createComponent();

    expect(findModal().exists()).toBe(true);
  });

  it('opens the modal when the disclosure button is clicked', async () => {
    createComponent();

    await findDisclosureDeleteButton().trigger('click');

    expect(createWrapper(wrapper.vm.$root).emitted(BV_SHOW_MODAL)).toHaveLength(1);
  });

  describe('modal', () => {
    describe('when model can be deleted', () => {
      beforeEach(() => {
        createComponent();
      });

      it('displays the correct title', () => {
        expect(findModal().props('title')).toBe('Delete self-hosted model');
      });

      it('displays the correct body', () => {
        expect(findModalText()).toMatchInterpolatedText(
          `You are about to delete the ${modelWithoutFeatureSettings.name} self-hosted model. This action cannot be undone.`,
        );
      });

      it('has a cancel button', () => {
        expect(findSecondaryButton().text()).toBe('Cancel');
      });

      describe('deleting a self-hosted model', () => {
        it('renders the button', () => {
          expect(findDeleteButton().text()).toBe('Delete');
        });

        it('invokes delete mutation', () => {
          findModal().vm.$emit('primary');

          expect(deleteMutationSuccessHandler).toHaveBeenCalledWith({
            input: { id: modelWithoutFeatureSettings.id },
          });
        });

        describe('when a deletion succeeds', () => {
          beforeEach(async () => {
            createComponent();

            findModal().vm.$emit('primary');

            await waitForPromises();
          });

          it('refreshes self-hosted model data', () => {
            expect(getSelfHostedModelsSuccessHandler).toHaveBeenCalled();
          });

          it('shows a success message', () => {
            expect(createAlert).toHaveBeenCalledWith(
              expect.objectContaining({
                message: 'Your self-hosted model was successfully deleted.',
              }),
            );
          });
        });

        describe('when a deletion fails', () => {
          const deleteMutationErrorHandler = jest.fn().mockResolvedValue({
            data: {
              aiSelfHostedModelDelete: {
                errors: ['Self-hosted model not found'],
              },
            },
          });

          beforeEach(() => {
            createComponent({
              apolloHandlers: [[deleteSelfHostedModelMutation, deleteMutationErrorHandler]],
            });
          });

          it('shows an error message', async () => {
            findModal().vm.$emit('primary');

            await waitForPromises();

            expect(createAlert).toHaveBeenCalledWith(
              expect.objectContaining({
                message: 'Self-hosted model not found',
              }),
            );
          });
        });
      });
    });

    describe('when model cannot be deleted', () => {
      beforeEach(() => {
        createComponent({ props: { model: modelWithFeatureSettings } });
      });

      it('displays the correct title', () => {
        expect(findModal().props('title')).toBe('This self-hosted model cannot be deleted');
      });

      it('displays the correct body', () => {
        const body = findModal().text();
        expect(body).toContain('mock-self-hosted-model-1');
        expect(body).toContain('Code Completion');
      });

      it('does not render the modal footer buttons', () => {
        expect(findModal().attributes('hidefooter')).toBe('true');
      });
    });
  });
});
