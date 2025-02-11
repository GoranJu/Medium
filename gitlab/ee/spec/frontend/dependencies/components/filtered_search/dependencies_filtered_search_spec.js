import { shallowMount } from '@vue/test-utils';
import { GlFilteredSearch } from '@gitlab/ui';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';
import createStore from 'ee/dependencies/store';
import { markRaw } from '~/lib/utils/vue3compat/mark_raw';

describe('DependenciesFilteredSearch', () => {
  let wrapper;
  let store;

  const defaultToken = {
    title: 'Component',
    type: 'component_names',
    multiSelect: true,
    token: markRaw(ComponentToken),
  };

  const defaultPropsData = {
    filteredSearchId: 'some-filtered-search-id',
    viewOnly: false,
    tokens: [defaultToken],
  };

  const createVuexStore = () => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();
  };

  const createComponent = ({ props = {}, slot = '' } = {}) => {
    wrapper = shallowMount(DependenciesFilteredSearch, {
      store,
      propsData: {
        ...defaultPropsData,
        ...props,
      },
      provide: {
        belowGroupLimit: true,
      },
      scopedSlots: { default: slot },
    });
  };

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);

  beforeEach(createVuexStore);

  describe('GlFilteredSearch', () => {
    beforeEach(createComponent);

    it('sets the basic props correctly', () => {
      const { viewOnly } = defaultPropsData;
      expect(findFilteredSearch().props()).toMatchObject({
        viewOnly,
        termsAsTokens: true,
      });
    });

    it('sets the id attribute', () => {
      const { filteredSearchId } = defaultPropsData;
      expect(findFilteredSearch().attributes('id')).toBe(filteredSearchId);
    });

    it('displays the correct placeholder', () => {
      expect(findFilteredSearch().props('placeholder')).toBe('Search or filter dependencies...');
    });

    it('passes the token configuration', () => {
      expect(findFilteredSearch().props('availableTokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            ...defaultToken,
          }),
        ]),
      );
    });

    describe('submit', () => {
      beforeEach(createComponent);

      it('dispatches the "fetchDependencies" Vuex action and resets the pagination', () => {
        expect(store.dispatch).not.toHaveBeenCalled();

        const filterPayload = [{ type: 'license', value: { data: ['MIT'] } }];
        findFilteredSearch().vm.$emit('submit', filterPayload);

        expect(store.dispatch).toHaveBeenCalledWith('allDependencies/fetchDependencies', {
          page: 1,
        });
      });
    });
  });
});
