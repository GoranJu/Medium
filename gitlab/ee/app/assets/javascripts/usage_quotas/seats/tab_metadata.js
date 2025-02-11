// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { __ } from '~/locale';
import { parseBoolean } from '~/lib/utils/common_utils';
import apolloProvider from '../shared/provider';
import { writeDataToApolloCache as writeSeatsDataToApolloCache } from './graphql/utils';
import initialSeatUsageStore from './store';
import SeatUsageApp from './components/subscription_seats.vue';

export const parseProvideData = (el) => {
  const {
    fullPath,
    namespaceId,
    namespaceName,
    isPublicNamespace,
    seatUsageExportPath,
    addSeatsHref,
    subscriptionHistoryHref,
    hasNoSubscription,
    maxFreeNamespaceSeats,
    explorePlansPath,
    enforcementFreeUserCapEnabled,
  } = el.dataset;

  return {
    fullPath,
    namespaceId: parseInt(namespaceId, 10),
    namespaceName,
    isPublicNamespace: parseBoolean(isPublicNamespace),
    seatUsageExportPath,
    addSeatsHref,
    subscriptionHistoryHref,
    hasNoSubscription: parseBoolean(hasNoSubscription),
    maxFreeNamespaceSeats: parseInt(maxFreeNamespaceSeats, 10),
    explorePlansPath,
    enforcementFreeUserCapEnabled: parseBoolean(enforcementFreeUserCapEnabled),
  };
};

export const getSeatTabMetadata = ({ includeEl = false } = {}) => {
  const el = document.querySelector('#js-seat-usage-app');

  if (!el) return false;

  const {
    fullPath,
    namespaceId,
    namespaceName,
    isPublicNamespace,
    seatUsageExportPath,
    addSeatsHref,
    subscriptionHistoryHref,
    hasNoSubscription,
    maxFreeNamespaceSeats,
    explorePlansPath,
    enforcementFreeUserCapEnabled,
  } = parseProvideData(el);

  const store = new Vuex.Store(
    initialSeatUsageStore({
      namespaceId,
      maxFreeNamespaceSeats,
      enforcementFreeUserCapEnabled,
    }),
  );

  const seatTabMetadata = {
    title: __('Seats'),
    hash: '#seats-quota-tab',
    testid: 'seats-tab',
    component: {
      name: 'SeatUsageTab',
      apolloProvider: writeSeatsDataToApolloCache(apolloProvider, { subscriptionId: namespaceId }),
      provide: {
        subscriptionHistoryHref,
        explorePlansPath,
        fullPath,
        isPublicNamespace,
        namespaceId,
        namespaceName,
        addSeatsHref,
        seatUsageExportPath,
        hasNoSubscription,
      },
      store,
      render(createElement) {
        return createElement(SeatUsageApp);
      },
    },
  };

  if (includeEl) {
    seatTabMetadata.component.el = el;
  }

  return seatTabMetadata;
};
