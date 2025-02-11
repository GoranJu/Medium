import Vue from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlLink, GlSprintf } from '@gitlab/ui';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import GeoReplicableItem from 'ee/geo_replicable/components/geo_replicable_item.vue';
import GeoReplicableStatus from 'ee/geo_replicable/components/geo_replicable_status.vue';
import GeoReplicableTimeAgo from 'ee/geo_replicable/components/geo_replicable_time_ago.vue';
import { ACTION_TYPES } from 'ee/geo_replicable/constants';
import { getStoreConfig } from 'ee/geo_replicable/store';
import {
  MOCK_BASIC_GRAPHQL_DATA,
  MOCK_REPLICABLE_TYPE,
  MOCK_REPLICABLE_BASE_PATH,
} from '../mock_data';

Vue.use(Vuex);

describe('GeoReplicableItem', () => {
  let wrapper;
  const mockReplicable = MOCK_BASIC_GRAPHQL_DATA[0];

  const actionSpies = {
    initiateReplicableAction: jest.fn(),
  };

  const defaultProps = {
    name: mockReplicable.name,
    registryId: mockReplicable.id,
    modelRecordId: 11,
    syncStatus: mockReplicable.state,
    lastSynced: mockReplicable.lastSyncedAt,
    lastVerified: mockReplicable.verifiedAt,
  };

  const createComponent = (props = {}, state = {}, featureFlags = {}) => {
    const store = new Vuex.Store({
      ...getStoreConfig({
        replicableType: MOCK_REPLICABLE_TYPE,
        ...state,
      }),
      actions: actionSpies,
    });

    wrapper = shallowMountExtended(GeoReplicableItem, {
      store,
      propsData: {
        ...defaultProps,
        ...props,
      },
      provide: { replicableBasePath: MOCK_REPLICABLE_BASE_PATH, glFeatures: { ...featureFlags } },
    });
  };

  const findReplicableItemHeader = () => wrapper.findByTestId('replicable-item-header');
  const findReplicableItemSyncStatus = () =>
    findReplicableItemHeader().findComponent(GeoReplicableStatus);
  const findResyncButton = () => wrapper.findByTestId('geo-resync-item');
  const findReverifyButton = () => wrapper.findByTestId('geo-reverify-item');
  const findReplicableItemNoLinkText = () => findReplicableItemHeader().find('span');
  const findReplicableDetailsLink = () => wrapper.findComponent(GlLink);
  const findReplicableItemTimeAgos = () => wrapper.findAllComponents(GeoReplicableTimeAgo);
  const findReplicableTimeAgosDateStrings = () =>
    findReplicableItemTimeAgos().wrappers.map((w) => w.props('dateString'));
  const findReplicableTimeAgosDefaultTexts = () =>
    findReplicableItemTimeAgos().wrappers.map((w) => w.props('defaultText'));
  const findReplicableItemModelRecordId = () => wrapper.findComponent(GlSprintf);

  describe.each`
    verificationEnabled | showResyncAction | showReverifyAction
    ${false}            | ${true}          | ${false}
    ${true}             | ${true}          | ${true}
  `('template', ({ verificationEnabled, showResyncAction, showReverifyAction }) => {
    describe(`when verificationEnabled is ${verificationEnabled}`, () => {
      beforeEach(() => {
        createComponent(null, { verificationEnabled });
      });

      it('renders GeoReplicableStatus', () => {
        expect(findReplicableItemSyncStatus().exists()).toBe(true);
      });

      it(`${showResyncAction ? 'does' : 'does not'} render Resync Button`, () => {
        expect(findResyncButton().exists()).toBe(showResyncAction);
      });

      it(`${showReverifyAction ? 'does' : 'does not'} render Reverify Button`, () => {
        expect(findReverifyButton().exists()).toBe(showReverifyAction);
      });
    });
  });

  describe('list item title', () => {
    describe('when geoReplicablesShowView is false', () => {
      beforeEach(() => {
        createComponent(null, null, { geoReplicablesShowView: false });
      });

      it('renders as plain text', () => {
        expect(findReplicableItemNoLinkText().text()).toBe(mockReplicable.name);
      });

      it('does not render a link', () => {
        expect(findReplicableDetailsLink().exists()).toBe(false);
      });
    });

    describe('when geoReplicablesShowView is true', () => {
      beforeEach(() => {
        createComponent(null, null, { geoReplicablesShowView: true });
      });

      it('does not render as plain text', () => {
        expect(findReplicableItemNoLinkText().exists()).toBe(false);
      });

      it('renders a link', () => {
        expect(findReplicableDetailsLink().attributes('href')).toBe(
          `${MOCK_REPLICABLE_BASE_PATH}/${getIdFromGraphQLId(mockReplicable.id)}`,
        );
      });
    });
  });

  describe('Resync button action', () => {
    beforeEach(() => {
      createComponent(null, null);
    });

    it('calls initiateReplicableAction when clicked', () => {
      findResyncButton().vm.$emit('click');

      expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
        registryId: defaultProps.registryId,
        name: defaultProps.name,
        action: ACTION_TYPES.RESYNC,
      });
    });
  });

  describe('Reverify button action', () => {
    beforeEach(() => {
      createComponent(null, { verificationEnabled: true });
    });

    it('calls initiateReplicableAction when clicked', () => {
      findReverifyButton().vm.$emit('click');

      expect(actionSpies.initiateReplicableAction).toHaveBeenCalledWith(expect.any(Object), {
        registryId: defaultProps.registryId,
        name: defaultProps.name,
        action: ACTION_TYPES.REVERIFY,
      });
    });
  });

  describe('when verificationEnabled is true', () => {
    beforeEach(() => {
      createComponent(null, { verificationEnabled: 'true' });
    });

    it('renders GeoReplicableTimeAgo component for each element in timeAgoArray', () => {
      expect(findReplicableItemTimeAgos().length).toBe(2);
    });

    it('passes the correct date strings to the GeoReplicableTimeAgo component', () => {
      expect(findReplicableTimeAgosDateStrings().length).toBe(2);
      expect(findReplicableTimeAgosDateStrings()).toStrictEqual([
        mockReplicable.lastSyncedAt,
        mockReplicable.verifiedAt,
      ]);
    });

    it('passes the correct date defaultTexts to the GeoReplicableTimeAgo component', () => {
      expect(findReplicableTimeAgosDefaultTexts().length).toBe(2);
      expect(findReplicableTimeAgosDefaultTexts()).toStrictEqual([
        GeoReplicableItem.i18n.unknown,
        GeoReplicableItem.i18n.unknown,
      ]);
    });
  });

  describe('when verificationEnabled is false', () => {
    beforeEach(() => {
      createComponent(null, { verificationEnabled: 'false' });
    });

    it('renders GeoReplicableTimeAgo component for each element in timeAgoArray', () => {
      expect(findReplicableItemTimeAgos().length).toBe(2);
    });

    it('passes the correct date strings to the GeoReplicableTimeAgo component', () => {
      expect(findReplicableTimeAgosDateStrings().length).toBe(2);
      expect(findReplicableTimeAgosDateStrings()).toStrictEqual([
        mockReplicable.lastSyncedAt,
        mockReplicable.verifiedAt,
      ]);
    });

    it('passes the correct date defaultTexts to the GeoReplicableTimeAgo component', () => {
      expect(findReplicableTimeAgosDefaultTexts().length).toBe(2);
      expect(findReplicableTimeAgosDefaultTexts()).toStrictEqual([
        GeoReplicableItem.i18n.unknown,
        GeoReplicableItem.i18n.nA,
      ]);
    });
  });

  it('renders a model record id', () => {
    createComponent();

    expect(findReplicableItemModelRecordId().attributes('message')).toBe(
      'Model record: %{modelRecordId}',
    );
  });
});
