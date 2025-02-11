import {
  GlPagination,
  GlButton,
  GlTable,
  GlAvatarLink,
  GlAvatarLabeled,
  GlBadge,
  GlModal,
  GlTooltip,
} from '@gitlab/ui';
import { mount, shallowMount } from '@vue/test-utils';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import SubscriptionUserList, {
  FIVE_MINUTES_IN_MS,
} from 'ee/usage_quotas/seats/components/subscription_user_list.vue';
import {
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX,
  DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX,
  SORT_OPTIONS,
} from 'ee/usage_quotas/seats/constants';
import getStoreConfig from 'ee/usage_quotas/seats/store';
import { REMOVE_BILLABLE_MEMBER_SUCCESS } from 'ee/usage_quotas/seats/store/mutation_types';
import { mockTableItems } from 'ee_jest/usage_quotas/seats/mock_data';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import SearchAndSortBar from '~/usage_quotas/components/search_and_sort_bar/search_and_sort_bar.vue';
import { useFakeDate } from 'helpers/fake_date';

Vue.use(Vuex);

const MOCK_SEAT_USAGE_EXPORT_PATH = '/groups/test_group/-/seat_usage.csv';

const actionSpies = {
  setBillableMemberToRemove: jest.fn(),
  setSearchQuery: jest.fn(),
};

const defaultProvide = {
  subscriptionHistoryHref: '/groups/my-group/-/usage_quotas/subscription_history.csv',
  glFeatures: {
    billableMemberAsyncDeletion: true,
  },
  seatUsageExportPath: MOCK_SEAT_USAGE_EXPORT_PATH,
};

const defaultProps = {
  hasFreePlan: false,
};

const fakeStore = ({ initialState, initialGetters }) =>
  new Vuex.Store({
    actions: actionSpies,
    mutations: getStoreConfig().mutations,
    getters: {
      tableItems: () => mockTableItems,
      isLoading: () => false,
      ...initialGetters,
    },
    state: {
      hasError: false,
      namespaceId: 1,
      total: 300,
      page: 1,
      perPage: 5,
      sort: 'last_activity_on_desc',
      removedBillableMemberId: null,
      ...initialState,
    },
  });

describe('SubscriptionUserList', () => {
  useLocalStorageSpy();
  useFakeDate('2025-03-16T15:00:00.000Z');

  let store;
  let wrapper;

  const localStorageKey = `13-${DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX}`;
  const localStorageExpireKey = `13-${DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX}`;
  const fiveMinutesBeforeNow = () => new Date().getTime() - FIVE_MINUTES_IN_MS;
  const fiveMinutesFromNow = () => new Date().getTime() + FIVE_MINUTES_IN_MS;

  const createComponent = ({
    mountFn = shallowMount,
    initialState = {},
    initialGetters = {},
    provide = {},
    props = {},
  } = {}) => {
    store = fakeStore({ initialGetters, initialState });
    wrapper = extendedWrapper(
      mountFn(SubscriptionUserList, {
        store,
        provide: {
          ...defaultProvide,
          ...provide,
        },
        propsData: {
          ...defaultProps,
          ...props,
        },
        stubs: {
          SearchAndSortBar: true,
        },
      }),
    );
  };

  const findTable = () => wrapper.findComponent(GlTable);
  const findExportButton = () => wrapper.findByTestId('export-button');
  const findExportSeatUsageHistoryButton = () =>
    wrapper.findByTestId('subscription-seat-usage-history');
  const findSearchAndSortBar = () => wrapper.findComponent(SearchAndSortBar);
  const findPagination = () => wrapper.findComponent(GlPagination);
  const findAllRemoveUserItems = () => wrapper.findAllByTestId('remove-user');
  const findRemoveMemberItem = (id) => wrapper.find(`[id="remove-member-${id}"]`);
  const findErrorModal = () => wrapper.findComponent(GlModal);

  const serializeTableRow = (rowWrapper) => {
    const emailWrapper = rowWrapper.find('[data-testid="email"]');

    return {
      email: emailWrapper.text(),
      tooltip: emailWrapper.find('span').attributes('title'),
      removeUserButtonExists: rowWrapper.findComponent(GlButton).exists(),
      lastActivityOn: rowWrapper.find('[data-testid="last_activity_on"]').text(),
      lastLoginAt: rowWrapper.find('[data-testid="last_login_at"]').text(),
    };
  };

  const findSerializedTable = (tableWrapper) => {
    return tableWrapper.findAll('tbody tr').wrappers.map(serializeTableRow);
  };

  afterEach(() => {
    localStorage.clear();
  });

  describe('renders', () => {
    beforeEach(() => {
      createComponent({
        mountFn: mount,
        initialGetters: {
          tableItems: () => mockTableItems,
        },
      });
    });

    describe('export button', () => {
      it('has the correct href', () => {
        expect(findExportButton().attributes().href).toBe(MOCK_SEAT_USAGE_EXPORT_PATH);
      });
    });

    describe('ExportSeatUsageHistoryButton', () => {
      it('has the correct href', () => {
        expect(findExportSeatUsageHistoryButton().attributes().href).toBe(
          defaultProvide.subscriptionHistoryHref,
        );
      });

      describe('with a Free Plan', () => {
        beforeEach(() => {
          createComponent({
            mountFn: mount,
            initialGetters: {
              tableItems: () => mockTableItems,
            },
            props: {
              hasFreePlan: true,
            },
          });
        });

        it('does not render if plan is free', () => {
          expect(findExportSeatUsageHistoryButton().exists()).toBe(false);
        });
      });
    });

    describe('table content', () => {
      it('renders the correct data', () => {
        const serializedTable = findSerializedTable(findTable());

        expect(serializedTable).toMatchSnapshot();
      });
    });

    it('pagination is rendered and passed correct values', () => {
      const pagination = findPagination();

      expect(pagination.props()).toMatchObject({
        perPage: 5,
        totalItems: 300,
      });
    });

    describe('with error modal', () => {
      it('does not render the modal if the user is not removable', async () => {
        await findAllRemoveUserItems().at(0).trigger('click');

        expect(findErrorModal().html()).toBe('');
      });

      it('renders the error modal if the user is removable', async () => {
        await findAllRemoveUserItems().at(2).trigger('click');

        expect(findErrorModal().text()).toContain(CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT);
      });
    });

    describe('when removing a billable user', () => {
      const [{ user }] = mockTableItems;

      describe('with billableMemberAsyncDeletion enabled', () => {
        beforeEach(() => {
          createComponent({ initialState: { namespaceId: 13 } });
          return store.commit(REMOVE_BILLABLE_MEMBER_SUCCESS, { memberId: user.id });
        });

        it('sets the local storage key for the member id', () => {
          expect(localStorage.setItem).toHaveBeenCalledWith(localStorageKey, `[${user.id}]`);
        });

        it('sets the local storage key for expiration', () => {
          expect(localStorage.setItem).toHaveBeenCalledWith(
            localStorageExpireKey,
            fiveMinutesFromNow(),
          );
        });

        describe('when removing another member', () => {
          it('sets the local storage key for the member id', async () => {
            store.commit(REMOVE_BILLABLE_MEMBER_SUCCESS, { memberId: 13 });

            await nextTick();

            expect(localStorage.setItem).toHaveBeenLastCalledWith(
              localStorageKey,
              `[${user.id},13]`,
            );
          });

          it('sets the local storage key for expiration', () => {
            expect(localStorage.setItem).toHaveBeenCalledWith(
              localStorageExpireKey,
              fiveMinutesFromNow(),
            );
          });
        });
      });

      describe('with billableMemberAsyncDeletion disabled', () => {
        beforeEach(() => {
          createComponent({
            initialState: { namespaceId: 13 },
            provide: {
              glFeatures: {
                billableMemberAsyncDeletion: false,
              },
            },
          });
          return store.commit(REMOVE_BILLABLE_MEMBER_SUCCESS, { memberId: user.id });
        });

        it('does not set items in the local storage', () => {
          expect(localStorage.setItem).not.toHaveBeenCalled();
        });
      });
    });

    describe('when the removed billable user is set', () => {
      const selectedItem = 0;
      const { user } = mockTableItems[selectedItem];

      beforeEach(() => {
        createComponent({ initialState: { removedBillableMemberId: user.id }, mountFn: mount });
      });

      it('disables the related remove button', () => {
        expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBe('disabled');
      });

      it('does not disable unrelated remove button', () => {
        expect(findAllRemoveUserItems().at(1).attributes().disabled).toBeUndefined();
      });

      it('shows a tooltip for related users', () => {
        expect(findRemoveMemberItem(user.id).findComponent(GlTooltip).text()).toBe(
          'This user is scheduled for removal.',
        );
      });

      it('does snot show a tooltip for unrelated user', () => {
        const [, { user: nonRemovedUser }] = mockTableItems;

        expect(findRemoveMemberItem(nonRemovedUser.id).findComponent(GlTooltip).exists()).toBe(
          false,
        );
      });

      describe('with billableMemberAsyncDeletion disabled', () => {
        beforeEach(() => {
          createComponent({
            initialState: { namespaceId: 13 },
            mountFn: mount,
            provide: {
              glFeatures: {
                billableMemberAsyncDeletion: false,
              },
            },
          });
        });

        it('does not disable the related remove button', () => {
          expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBeUndefined();
        });
      });
    });

    describe('when the removed billable user is in local storage', () => {
      const selectedItem = 0;
      const { user } = mockTableItems[selectedItem];

      beforeEach(() => {
        localStorage.setItem(localStorageKey, `[${user.id}]`);
        localStorage.setItem(localStorageExpireKey, fiveMinutesFromNow());
        createComponent({ initialState: { namespaceId: 13 }, mountFn: mount });
      });

      it('disables the related remove button', () => {
        expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBe('disabled');
      });

      it('does not disable unrelated remove button', () => {
        expect(findAllRemoveUserItems().at(1).attributes().disabled).toBeUndefined();
      });

      it('shows a tooltip for related users', () => {
        expect(findRemoveMemberItem(user.id).findComponent(GlTooltip).text()).toBe(
          'This user is scheduled for removal.',
        );
      });

      it('does snot show a tooltip for unrelated user', () => {
        const [, { user: nonRemovedUser }] = mockTableItems;

        expect(findRemoveMemberItem(nonRemovedUser.id).findComponent(GlTooltip).exists()).toBe(
          false,
        );
      });

      describe('when the local storage item is expired', () => {
        beforeEach(() => {
          localStorage.setItem(localStorageKey, `[${user.id}]`);
          localStorage.setItem(localStorageExpireKey, fiveMinutesBeforeNow());
          createComponent({ initialState: { namespaceId: 13 }, mountFn: mount });
        });

        it('does not disable the related remove button', () => {
          expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBeUndefined();
        });

        it('removes the local storage key', () => {
          expect(localStorage.removeItem).toHaveBeenCalledWith(localStorageKey);
        });
      });

      describe('when the local storage item does not match the user', () => {
        it('does not disable the related remove button', () => {
          localStorage.setItem(localStorageKey, `[11]`);
          localStorage.setItem(localStorageExpireKey, fiveMinutesFromNow());
          createComponent({ initialState: { namespaceId: 13 }, mountFn: mount });

          expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBeUndefined();
        });
      });

      describe('when the local storage item does not match namespace id', () => {
        it('does not disable the related remove button', () => {
          localStorage.setItem(localStorageKey, `[${user.id}]`);
          localStorage.setItem(localStorageExpireKey, fiveMinutesFromNow());
          createComponent({ initialState: { namespaceId: 11 }, mountFn: mount });

          expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBeUndefined();
        });
      });

      describe('when the local storage errors', () => {
        it('does not disable any remove button', () => {
          localStorage.setItem.mockImplementation(() => {
            throw new Error('This is an error');
          });
          createComponent({ initialState: { namespaceId: 11 }, mountFn: mount });

          expect(findAllRemoveUserItems().at(selectedItem).attributes().disabled).toBeUndefined();
        });
      });
    });

    describe('members labeled avatar', () => {
      it('shows the correct avatarLabeled length', () => {
        const avatarLabeledList = findTable().findAllComponents(GlAvatarLabeled);

        expect(avatarLabeledList).toHaveLength(6);
      });

      it('passes the correct props to avatarLabeled', () => {
        const avatarLabeled = findTable().findComponent(GlAvatarLabeled);

        expect(avatarLabeled.props()).toMatchObject({ label: 'Administrator', subLabel: '@root' });
      });
    });

    describe('members avatar', () => {
      it('shows the correct avatarLinks length', () => {
        const avatarLinks = findTable().findAllComponents(GlAvatarLink);

        expect(avatarLinks).toHaveLength(6);
      });

      it('passes the correct props to avatarLink', () => {
        const avatarLink = findTable().findComponent(GlAvatarLink);

        expect(avatarLink.attributes()).toMatchObject({
          alt: 'Administrator',
          href: 'path/to/administrator',
        });
      });

      it.each(['group_invite', 'project_invite'])(
        'shows the correct badge for membership_type %s',
        (membershipType) => {
          const avatarLinks = findTable().findAllComponents(GlAvatarLink);
          const badgeText = (
            membershipType.charAt(0).toUpperCase() + membershipType.slice(1)
          ).replace('_', ' ');

          avatarLinks.wrappers.forEach((avatarLinkWrapper) => {
            const currentMember = mockTableItems.find(
              (item) => item.user.name === avatarLinkWrapper.attributes().alt,
            );

            if (membershipType === currentMember.user.membership_type) {
              expect(avatarLinkWrapper.findComponent(GlBadge).text()).toBe(badgeText);
            }
          });
        },
      );
    });

    describe('members details always shown', () => {
      it.each`
        membershipType
        ${'project_invite'}
        ${'group_invite'}
        ${'project_member'}
        ${'group_member'}
      `(
        'when membershipType is $membershipType, shouldShowDetails will be true',
        ({ membershipType }) => {
          mockTableItems.forEach((item) => {
            const detailsExpandButtons = findTable().find(
              `[data-testid="toggle-seat-usage-details-${item.user.id}"]`,
            );

            if (membershipType === item.user.membership_type) {
              expect(detailsExpandButtons.exists()).toBe(true);
            }
          });
        },
      );
    });
  });

  describe('Loading state', () => {
    describe('when nothing is loading', () => {
      beforeEach(() => {
        createComponent();
      });

      it('displays the table in a non-busy state', () => {
        expect(findTable().attributes('busy')).toBe(undefined);
      });
    });

    describe.each([
      [true, false],
      [false, true],
    ])('busy when isLoading=%s and hasError=%s', (isLoading, hasError) => {
      beforeEach(() => {
        createComponent({
          initialGetters: { isLoading: () => isLoading },
          initialState: { hasError },
        });
      });

      it('displays table in busy state', () => {
        expect(findTable().attributes('busy')).toBe('true');
      });
    });
  });

  describe('search box', () => {
    beforeEach(() => {
      createComponent();
    });

    it('input event triggers the setSearchQuery action', () => {
      const SEARCH_STRING = 'search string';

      findSearchAndSortBar().vm.$emit('onFilter', SEARCH_STRING);

      expect(actionSpies.setSearchQuery).toHaveBeenCalledTimes(1);
      expect(actionSpies.setSearchQuery).toHaveBeenCalledWith(expect.any(Object), SEARCH_STRING);
    });

    it('contains the correct sort options', () => {
      expect(findSearchAndSortBar().props('sortOptions')).toMatchObject(SORT_OPTIONS);
    });
  });
});
