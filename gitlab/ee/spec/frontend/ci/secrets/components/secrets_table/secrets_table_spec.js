import { GlAlert, GlBadge, GlLabel, GlLoadingIcon, GlPagination, GlTableLite } from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import setWindowLocation from 'helpers/set_window_location_helper';
import waitForPromises from 'helpers/wait_for_promises';
import {
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  INITIAL_PAGE,
  NEW_ROUTE_NAME,
  PAGE_SIZE,
  POLL_INTERVAL,
  ENTITY_GROUP,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
} from 'ee/ci/secrets/constants';
import SecretsTable from 'ee/ci/secrets/components/secrets_table/secrets_table.vue';
import SecretActionsCell from 'ee/ci/secrets/components/secrets_table/secret_actions_cell.vue';
import { cacheConfig } from 'ee/ci/secrets/graphql/settings';
import getSecretsQuery from 'ee/ci/secrets/graphql/queries/client/get_secrets.query.graphql';
import getSecretManagerStatusQuery from 'ee/ci/secrets/graphql/queries/get_secret_manager_status.query.graphql';
import { mockGroupSecretsData, mockProjectSecretsData } from 'ee/ci/secrets/mock_data';
import { secretManagerStatusResponse } from '../../mock_data';

Vue.use(VueApollo);

describe('SecretsTable component', () => {
  let wrapper;
  let apolloProvider;
  let resolverMock;
  let mockSecretManagerStatus;

  const findAlert = () => wrapper.findComponent(GlAlert);
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findNewSecretButton = () => wrapper.findByTestId('new-secret-button');
  const findSecretsTable = () => wrapper.findComponent(GlTableLite);
  const findSecretsTableRows = () => findSecretsTable().find('tbody').findAll('tr');
  const findSecretsCount = () => wrapper.findByTestId('crud-count');
  const findSecretDetailsLink = () => wrapper.findByTestId('secret-details-link');
  const findSecretLabels = () => findSecretsTableRows().at(0).findAllComponents(GlLabel);
  const findSecretLastAccessed = () => wrapper.findByTestId('secret-last-accessed');
  const findSecretExpires = () => wrapper.findByTestId('secret-expiration');
  const findSecretCreatedAt = () => wrapper.findByTestId('secret-created-at');
  const findSecretStatus = (index) => wrapper.findAllComponents(GlBadge).at(index);
  const findSecretActionsCell = () => wrapper.findComponent(SecretActionsCell);
  const findPagination = () => wrapper.findComponent(GlPagination);

  const createComponent = async ({
    entity = 'group',
    secretsMockData = mockGroupSecretsData,
  } = {}) => {
    const mockPaginatedSecretsData = ({ offset, limit }) => ({
      data: {
        [entity]: {
          id: `${entity}Id`,
          fullPath: `path/to/${entity}`,
          secrets: {
            count: secretsMockData.length,
            nodes: secretsMockData.slice(offset, offset + limit),
          },
        },
      },
    });

    resolverMock = jest.fn().mockImplementation(mockPaginatedSecretsData);

    const handlers = [
      [getSecretManagerStatusQuery, mockSecretManagerStatus],
      [getSecretsQuery, resolverMock],
    ];
    apolloProvider = createMockApollo(handlers, undefined, cacheConfig);

    wrapper = mountExtended(SecretsTable, {
      propsData: {
        fullPath: `path/to/${entity}`,
        isGroup: entity === ENTITY_GROUP,
      },
      apolloProvider,
      stubs: {
        RouterLink: RouterLinkStub,
      },
    });

    await waitForPromises();
  };

  const advanceToNextFetch = (milliseconds) => {
    jest.advanceTimersByTime(milliseconds);
  };

  const pollNextStatus = async (status) => {
    mockSecretManagerStatus.mockResolvedValue(secretManagerStatusResponse(status));
    advanceToNextFetch(POLL_INTERVAL);

    await waitForPromises();
    await nextTick();
  };
  beforeEach(() => {
    mockSecretManagerStatus = jest.fn();
    mockSecretManagerStatus.mockResolvedValue(
      secretManagerStatusResponse(SECRET_MANAGER_STATUS_ACTIVE),
    );
  });

  afterEach(() => {
    apolloProvider = null;
  });

  describe('Secret Manager Status', () => {
    it('shows loading icon while status is being fetched', () => {
      createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findSecretsTable().exists()).toBe(false);
    });

    describe('when status is PROVISIONING', () => {
      beforeEach(async () => {
        mockSecretManagerStatus.mockResolvedValue(
          secretManagerStatusResponse(SECRET_MANAGER_STATUS_PROVISIONING),
        );

        await createComponent();
      });

      it('shows alert notice when status is provisioning', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findSecretsTable().exists()).toBe(false);
        expect(findAlert().exists()).toBe(true);
        expect(findAlert().props('dismissible')).toBe(false);
      });

      it('polls for status while provisioning', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(SECRET_MANAGER_STATUS_PROVISIONING);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(2);
      });
    });

    describe('when status is active', () => {
      beforeEach(async () => {
        await createComponent();
      });

      it('shows table when status is active', () => {
        expect(findLoadingIcon().exists()).toBe(false);
        expect(findAlert().exists()).toBe(false);
        expect(findSecretsTable().exists()).toBe(true);
      });

      it('stops polling for status', async () => {
        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);

        await pollNextStatus(SECRET_MANAGER_STATUS_ACTIVE);

        expect(mockSecretManagerStatus).toHaveBeenCalledTimes(1);
      });
    });
  });

  describe.each`
    entity       | secretsMockData
    ${'group'}   | ${mockGroupSecretsData}
    ${'project'} | ${mockProjectSecretsData}
  `('$entity secrets table', ({ entity, secretsMockData }) => {
    const secret = secretsMockData[0];

    beforeEach(async () => {
      await createComponent({ entity, secretsMockData });
    });

    it('shows a total count of secrets', () => {
      expect(findSecretsCount().text()).toBe(`${secretsMockData.length}`);
    });

    it('shows a link to the new secret page', () => {
      expect(findNewSecretButton().attributes('to')).toBe(NEW_ROUTE_NAME);
    });

    it('renders a table of secrets', () => {
      expect(findSecretsTable().exists()).toBe(true);
      expect(findSecretsTableRows().length).toBe(PAGE_SIZE);
    });

    it('shows the secret name as a link to the secret details', () => {
      expect(findSecretDetailsLink().text()).toBe(secret.name);
      expect(findSecretDetailsLink().props('to')).toMatchObject({
        name: DETAILS_ROUTE_NAME,
        params: { secretName: secret.name },
      });
    });

    it.each([0, 0])('shows the labels for a secret', (labelIndex) => {
      expect(findSecretLabels().at(labelIndex).props()).toMatchObject({
        title: 'env::production',
      });
    });

    it('shows when the secret was last accessed', () => {
      expect(findSecretLastAccessed().props('time')).toBe(secret.lastAccessed);
    });

    it('shows when the secret expires', () => {
      expect(findSecretExpires().props('date')).toBe(secret.expiration);
    });

    it('shows when the secret was created', () => {
      expect(findSecretCreatedAt().props('date')).toBe(secret.createdAt);
    });

    it.each`
      index | text               | variant      | icon
      ${0}  | ${'Enabled'}       | ${'success'} | ${'status-active'}
      ${1}  | ${'Disabled'}      | ${'neutral'} | ${'status-failed'}
      ${2}  | ${'Expiring soon'} | ${'warning'} | ${'status-alert'}
      ${3}  | ${'Expired'}       | ${'danger'}  | ${'status-cancelled'}
    `('shows $text secret status', ({ index, text, variant, icon }) => {
      expect(findSecretStatus(index).text()).toBe(text);
      expect(findSecretStatus(index).props('variant')).toBe(variant);
      expect(findSecretStatus(index).props('icon')).toBe(icon);
    });

    it('passes correct props to actions cell', () => {
      expect(findSecretActionsCell().props()).toMatchObject({
        detailsRoute: {
          name: EDIT_ROUTE_NAME,
          params: { id: secret.id },
        },
      });
    });
  });

  describe('pagination', () => {
    it.each`
      secretsCount     | description          | paginationShouldExist
      ${PAGE_SIZE - 1} | ${'does not render'} | ${false}
      ${PAGE_SIZE + 1} | ${'renders'}         | ${true}
    `(
      '$description when there are $secretsCount secrets',
      async ({ secretsCount, paginationShouldExist }) => {
        await createComponent({
          secretsMockData: mockGroupSecretsData.slice(0, secretsCount),
        });

        expect(findPagination().exists()).toBe(paginationShouldExist);
      },
    );

    it('starts on initial page by default', async () => {
      await createComponent();

      expect(findPagination().props('value')).toBe(INITIAL_PAGE);
    });

    it('starts on page from URL when provided', async () => {
      const page = 2;
      setWindowLocation(`?page=${page}`);
      await createComponent();

      expect(findPagination().props('value')).toBe(2);
      expect(resolverMock).toHaveBeenLastCalledWith(
        expect.objectContaining({
          offset: (page - 1) * PAGE_SIZE,
          limit: PAGE_SIZE,
        }),
      );
    });

    describe('page changes', () => {
      beforeEach(async () => {
        jest.spyOn(window.history, 'pushState');
        await createComponent();
      });

      it.each`
        fromPage | toPage
        ${1}     | ${2}
        ${2}     | ${1}
      `('updates when going from page $fromPage to $toPage', async ({ fromPage, toPage }) => {
        findPagination().vm.$emit('input', fromPage);
        findPagination().vm.$emit('input', toPage);

        // while the Secrets table is in CI/CD settings
        // we suppress URL changes for page changes
        // expect(window.history.pushState).toHaveBeenCalledWith(
        //   {},
        //   '',
        //   `http://test.host/?page=${toPage}`,
        // );

        await waitForPromises();

        // updates secrets data in table and page in pagination
        expect(findPagination().props('value')).toBe(toPage);
        expect(resolverMock).toHaveBeenLastCalledWith(
          expect.objectContaining({
            offset: (toPage - 1) * PAGE_SIZE,
            limit: PAGE_SIZE,
          }),
        );
      });
    });
  });
});
