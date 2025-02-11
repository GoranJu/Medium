import { shallowMount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { GlKeysetPagination } from '@gitlab/ui';
import DependenciesTable from 'ee/dependencies/components/dependencies_table.vue';
import PaginatedDependenciesTable from 'ee/dependencies/components/paginated_dependencies_table.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import TablePagination from '~/vue_shared/components/pagination/table_pagination.vue';
import * as urlUtility from '~/lib/utils/url_utility';
import { TEST_HOST } from 'helpers/test_constants';
import mockDependenciesResponse from '../store/modules/list/data/mock_dependencies.json';

describe('PaginatedDependenciesTable component', () => {
  let store;
  let wrapper;
  let originalDispatch;
  const { namespace } = DEPENDENCY_LIST_TYPES.all;

  const factory = (props = {}) => {
    store = createStore();

    wrapper = shallowMount(PaginatedDependenciesTable, {
      store,
      propsData: { ...props },
      provide: { vulnerabilitiesEndpoint: TEST_HOST },
    });
  };

  const findTablePagination = () => wrapper.findComponent(TablePagination);

  const expectComponentWithProps = (Component, props = {}) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.isVisible()).toBe(true);
    expect(componentWrapper.props()).toEqual(expect.objectContaining(props));
  };

  beforeEach(async () => {
    factory({ namespace });

    originalDispatch = store.dispatch;
    jest.spyOn(store, 'dispatch').mockImplementation();
    jest.spyOn(urlUtility, 'updateHistory');

    await nextTick();
  });

  describe('when dependencies are received successfully via offset pagination', () => {
    beforeEach(async () => {
      originalDispatch(`${namespace}/receiveDependenciesSuccess`, {
        data: mockDependenciesResponse,
        headers: { 'X-Total': mockDependenciesResponse.dependencies.length },
      });

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: mockDependenciesResponse.dependencies,
        isLoading: store.state[namespace].isLoading,
        vulnerabilityItemsLoading: store.state[namespace].vulnerabilityItemsLoading,
        vulnerabilityInfo: store.state[namespace].vulnerabilityInfo,
      });
    });
  });

  it('passes the correct props to the pagination', () => {
    expectComponentWithProps(TablePagination, {
      change: wrapper.vm.fetchPage,
      pageInfo: store.state[namespace].pageInfo,
    });
  });

  it('has a fetchPage method which dispatches the correct action', () => {
    const page = 2;
    wrapper.vm.fetchPage(page);
    expect(store.dispatch).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith(`${namespace}/fetchDependencies`, { page });
  });

  it('fetchCursorPage dispatches the correct action', () => {
    const cursor = 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9';
    wrapper.vm.fetchCursorPage(cursor);
    expect(store.dispatch).toHaveBeenCalledTimes(1);
    expect(store.dispatch).toHaveBeenCalledWith(`${namespace}/fetchDependencies`, { cursor });
    expect(urlUtility.updateHistory).toHaveBeenCalledTimes(1);
    expect(urlUtility.updateHistory).toHaveBeenCalledWith({
      url: `${TEST_HOST}/?cursor=${cursor}`,
    });
  });

  it('dispatches fetch vulnerabilities', async () => {
    const item = {};
    const table = wrapper.findComponent(DependenciesTable);
    await table.vm.$emit('row-click', item);

    expect(store.dispatch).toHaveBeenCalledWith(`${namespace}/fetchVulnerabilities`, {
      item,
      vulnerabilitiesEndpoint: TEST_HOST,
    });
  });

  describe('when the list is loading', () => {
    let module;

    beforeEach(async () => {
      module = store.state[namespace];
      module.isLoading = true;
      module.errorLoading = false;

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: module.dependencies,
        isLoading: true,
      });
    });

    it('does not render pagination', () => {
      expect(findTablePagination().exists()).toBe(false);
    });

    it('does not render keyset pagination', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(false);
    });
  });

  describe('when an error occured on load', () => {
    let module;

    beforeEach(async () => {
      module = store.state[namespace];
      module.isLoading = false;
      module.errorLoading = true;

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: module.dependencies,
        isLoading: false,
      });
    });

    it('does not render pagination', () => {
      expect(findTablePagination().exists()).toBe(false);
    });

    it('does not render keyset pagination', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(false);
    });
  });

  describe('when the list is empty', () => {
    let module;

    beforeEach(async () => {
      module = store.state[namespace];
      module.dependencies = [];
      module.pageInfo.total = 0;

      module.isLoading = false;
      module.errorLoading = false;

      await nextTick();
    });

    it('passes the correct props to the dependencies table', () => {
      expectComponentWithProps(DependenciesTable, {
        dependencies: module.dependencies,
        isLoading: false,
      });
    });

    it('renders pagination', () => {
      expect(findTablePagination().exists()).toBe(true);
    });
  });

  describe('when dependencies are received successfully via cursor pagination', () => {
    beforeEach(async () => {
      originalDispatch(`${namespace}/receiveDependenciesSuccess`, {
        data: mockDependenciesResponse,
        headers: {
          'X-Page-Type': 'cursor',
          'X-Next-Page': 'eyJpZCI6IjQyIiwiX2tkIjoibiJ9',
          'X-Prev-Page': '',
        },
      });

      await nextTick();
    });

    it('does not render offset pagination', () => {
      expect(findTablePagination().exists()).toBe(false);
    });

    it('renders keyset pagination', () => {
      expect(wrapper.findComponent(GlKeysetPagination).exists()).toBe(true);
    });
  });
});
