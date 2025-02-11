import { GlSorting } from '@gitlab/ui';
import { nextTick } from 'vue';
import DependenciesActions from 'ee/dependencies/components/dependencies_actions.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import { SORT_FIELDS } from 'ee/dependencies/store/modules/list/constants';
import * as urlUtility from '~/lib/utils/url_utility';
import { TEST_HOST } from 'helpers/test_constants';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('DependenciesActions component', () => {
  let store;
  let wrapper;
  const { namespace } = DEPENDENCY_LIST_TYPES.all;

  const factory = ({ propsData, provide, glFeatures = { projectComponentFilter: true } } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    wrapper = shallowMountExtended(DependenciesActions, {
      store,
      propsData: {
        namespace,
        ...propsData,
      },
      provide: {
        namespaceType: 'group',
        ...provide,
        glFeatures,
      },
      stubs: {
        GroupDependenciesFilteredSearch: true,
        ProjectDependenciesFilteredSearch: true,
      },
    });
  };

  const findSorting = () => wrapper.findComponent(GlSorting);
  const emitSortByChange = (value) => findSorting().vm.$emit('sortByChange', value);

  describe('Filtered Search', () => {
    describe.each`
      namespaceType | componentName
      ${'group'}    | ${'GroupDependenciesFilteredSearch'}
      ${'project'}  | ${'ProjectDependenciesFilteredSearch'}
    `('with namespaceType set to $namespaceType', ({ namespaceType, componentName }) => {
      it('renders the correct filtered search component', () => {
        factory({
          provide: { namespaceType },
        });

        expect(wrapper.findComponent({ name: componentName }).exists()).toBe(true);
      });
    });

    describe('when feature flag "projectComponentFilter" is disabled', () => {
      it('does not render filtered search component', () => {
        factory({
          provide: { namespaceType: 'project' },
          glFeatures: { projectComponentFilter: false },
        });
        expect(wrapper.findComponent({ name: 'ProjectDependenciesFilteredSearch' }).exists()).toBe(
          false,
        );
        expect(wrapper.findComponent({ name: 'GroupDependenciesFilteredSearch' }).exists()).toBe(
          false,
        );
      });
    });
  });

  describe('Sorting', () => {
    beforeEach(async () => {
      factory();
      store.state[namespace].endpoint = `${TEST_HOST}/dependencies.json`;
      jest.spyOn(urlUtility, 'updateHistory');
      await nextTick();
    });

    it('renders the tooltip', () => {
      expect(findSorting().props('sortDirectionToolTip')).toBe('Sort direction');
    });

    it('dispatches the right setSortField action on clicking each item in the dropdown', () => {
      Object.keys(SORT_FIELDS).forEach((field) => {
        emitSortByChange(field);
      });

      expect(store.dispatch.mock.calls).toEqual(
        expect.arrayContaining(
          Object.keys(SORT_FIELDS).map((field) => [`${namespace}/setSortField`, field]),
        ),
      );
    });

    it('dispatches the toggleSortOrder action on clicking the sort order button', () => {
      findSorting().vm.$emit('sortDirectionChange');

      expect(store.dispatch).toHaveBeenCalledWith(`${namespace}/toggleSortOrder`);
      expect(urlUtility.updateHistory).toHaveBeenCalledTimes(1);
      expect(urlUtility.updateHistory).toHaveBeenCalledWith({
        url: `${TEST_HOST}/`,
      });
    });
  });
});
