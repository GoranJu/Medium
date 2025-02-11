import { GlDisclosureDropdownItem } from '@gitlab/ui';
import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import { DETAILS_ROUTE_NAME } from 'ee/ci/secrets/constants';
import SecretActionsCell from 'ee/ci/secrets/components/secrets_table/secret_actions_cell.vue';

describe('SecretActionsCell component', () => {
  let wrapper;

  const findSecretActionItems = () => wrapper.findAllComponents(GlDisclosureDropdownItem);

  const createComponent = () => {
    wrapper = mountExtended(SecretActionsCell, {
      propsData: {
        detailsRoute: { name: DETAILS_ROUTE_NAME, params: { key: 'secret_key' } },
      },
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });
  };

  beforeEach(() => {
    createComponent();
  });

  it('shows the actions dropdown for the secret', () => {
    expect(findSecretActionItems().length).toBe(3);
  });

  it('shows the "Edit secret" action', () => {
    const action = findSecretActionItems().at(0);

    expect(action.text()).toBe('Edit secret');
    expect(action.findComponent(RouterLinkStub).props('to')).toMatchObject({
      name: DETAILS_ROUTE_NAME,
      params: { key: 'secret_key' },
    });
  });

  it('shows the "Delete" action', () => {
    const action = findSecretActionItems().at(1);

    expect(action.text()).toBe('Delete');
  });

  it('shows the "Revoke" action', () => {
    const action = findSecretActionItems().at(2);

    expect(action.text()).toBe('Revoke');
  });
});
