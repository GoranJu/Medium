import { nextTick } from 'vue';
import { GlCollapsibleListbox, GlListboxItem } from '@gitlab/ui';
import waitForPromises from 'helpers/wait_for_promises';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import RunnerTagsDropdown from 'ee/vue_shared/components/runner_tags_dropdown/runner_tags_dropdown.vue';
import { getUniqueTagListFromEdges } from 'ee/vue_shared/components/runner_tags_dropdown/utils';
import { NAMESPACE_TYPES } from 'ee/security_orchestration/constants';
import { createMockApolloProvider, PROJECT_ID } from './mocks/apollo_mock';
import { RUNNER_TAG_LIST_MOCK } from './mocks/mocks';

describe('RunnerTagsDropdown', () => {
  let wrapper;
  let handlers;

  const emptyTagListHandler = jest.fn().mockResolvedValue({
    data: {
      project: {
        id: PROJECT_ID,
        runners: {
          nodes: [],
        },
      },
    },
  });

  const createComponent = (propsData = {}, apolloOptions = { handlers: undefined }) => {
    const { requestHandlers, apolloProvider } = createMockApolloProvider(apolloOptions);
    handlers = requestHandlers;

    wrapper = mountExtended(RunnerTagsDropdown, {
      apolloProvider,
      propsData: {
        namespacePath: 'gitlab-org/testPath',
        ...propsData,
      },
      stubs: {
        GlListboxItem,
      },
    });
  };

  const findTagsList = () => wrapper.findComponent(GlCollapsibleListbox);
  const findDropdownItems = () => findTagsList().findAllComponents(GlListboxItem);
  const findSearchBox = () => wrapper.findByTestId('listbox-search-input');
  const toggleDropdown = (event = 'shown') => {
    findTagsList().vm.$emit(event);
  };

  beforeEach(async () => {
    createComponent();
    await waitForPromises();
  });

  it('should load data', () => {
    expect(handlers.projectRequestHandler).toHaveBeenCalledTimes(1);
    expect(handlers.projectRequestHandler).toHaveBeenCalledWith({
      fullPath: 'gitlab-org/testPath',
      tagList: '',
    });
    expect(findDropdownItems()).toHaveLength(5);
    expect(wrapper.emitted('tags-loaded')).toHaveLength(1);
    expect(wrapper.emitted('tags-loaded')[0][0]).toEqual([
      'macos',
      'linux',
      'docker',
      'backup',
      'development',
    ]);
  });

  it('should select tags', async () => {
    toggleDropdown();
    await waitForPromises();
    findDropdownItems().at(0).vm.$emit('select', ['macos']);
    await nextTick();
    findDropdownItems().at(2).vm.$emit('select', ['docker']);
    await nextTick();

    expect(wrapper.emitted('input')).toHaveLength(2);
  });

  it('should filter out results by search', async () => {
    toggleDropdown();

    expect(findDropdownItems()).toHaveLength(
      getUniqueTagListFromEdges(RUNNER_TAG_LIST_MOCK).length,
    );

    findSearchBox().vm.$emit('input', 'macos');
    await nextTick();
    expect(handlers.projectRequestHandler).toHaveBeenCalledWith({
      fullPath: 'gitlab-org/testPath',
      tagList: 'macos',
    });
  });

  it('should render selected tags on top after re-open', async () => {
    toggleDropdown();

    expect(findDropdownItems().at(3).text()).toEqual('backup');
    expect(findDropdownItems().at(4).text()).toEqual('development');

    findDropdownItems().at(3).vm.$emit('select', ['backup']);
    await nextTick();
    findDropdownItems().at(4).vm.$emit('select', ['development']);

    /**
     * close - open dropdown
     */
    toggleDropdown('hidden');
    await nextTick();
    toggleDropdown();

    expect(findDropdownItems().at(0).text()).toEqual('development');
    expect(findDropdownItems().at(1).text()).toEqual('backup');
  });

  it('should emit select event', () => {
    toggleDropdown();

    findDropdownItems().at(0).trigger('click');

    expect(wrapper.emitted('input')).toHaveLength(1);
  });

  it('renders custom header', async () => {
    const testHeader = 'Test header';

    createComponent({ headerText: testHeader });
    await waitForPromises();

    expect(findTagsList().props('headerText')).toBe(testHeader);
  });

  describe('toggle text', () => {
    it('renders default text', async () => {
      createComponent();
      await waitForPromises();
      expect(findTagsList().props('toggleText')).toBe('Select runner tags');
    });

    it('renders selected tags', async () => {
      createComponent();
      await waitForPromises();
      toggleDropdown();
      await waitForPromises();
      findDropdownItems().at(0).vm.$emit('select', ['macos']);
      await nextTick();
      findDropdownItems().at(2).vm.$emit('select', ['docker']);
      await nextTick();

      expect(findTagsList().props('toggleText')).toBe('macos, docker');
    });

    it('renders selected tags if search is empty, but tags are already selected', async () => {
      createComponent({ value: ['macos'] }, { handlers: emptyTagListHandler });
      await waitForPromises();
      await findTagsList().vm.$emit('select', ['macos']);
      expect(findTagsList().props('toggleText')).toBe('macos');
    });

    it('renders custom placeholder for empty lists', async () => {
      const emptyTagsListPlaceholder = 'emptyTagsListPlaceholder';
      createComponent({ emptyTagsListPlaceholder }, { handlers: emptyTagListHandler });
      await waitForPromises();

      expect(findTagsList().props('toggleText')).toBe(emptyTagsListPlaceholder);
    });

    it('renders default text for empty lists', async () => {
      createComponent({}, { handlers: emptyTagListHandler });
      await waitForPromises();

      expect(findTagsList().props('toggleText')).toBe('No tags exist');
    });
  });

  describe('disabled state', () => {
    it('disables listbox with props', async () => {
      createComponent({ disabled: true });
      await waitForPromises();

      expect(findTagsList().props('disabled')).toBe(true);
    });

    it('disables listbox for empty lists when not searching', async () => {
      createComponent({}, { handlers: emptyTagListHandler });
      await waitForPromises();
      expect(findTagsList().props('disabled')).toBe(true);
    });

    it('does not disable the listbox for empty lists when searching', async () => {
      createComponent({}, { handlers: emptyTagListHandler });
      await waitForPromises();
      await findTagsList().vm.$emit('search', 'macos');
      expect(findTagsList().props('disabled')).toBe(false);
    });
  });

  describe('error handling', () => {
    it('should emit error event', async () => {
      createComponent({}, { handlers: jest.fn().mockRejectedValue({ error: new Error() }) });
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });

    it('should emit error when invalid tag is provided or saved', async () => {
      createComponent({
        value: ['invalid tag'],
      });
      await waitForPromises();

      expect(wrapper.emitted('error')).toHaveLength(1);
    });
  });

  describe('selected tags', () => {
    const savedOnBackendTags = ['linux', 'macos'];

    beforeEach(async () => {
      createComponent({ value: savedOnBackendTags });
      await waitForPromises();
    });

    it('should render saved on backend selected tags', () => {
      toggleDropdown();
      expect(findDropdownItems().at(0).text()).toBe('linux');
      expect(findDropdownItems().at(1).text()).toBe('macos');

      expect(findDropdownItems().at(0).props('isSelected')).toBe(true);
      expect(findDropdownItems().at(1).props('isSelected')).toBe(true);
    });
  });

  describe('no runners', () => {
    beforeEach(async () => {
      const savedOnBackendTags = ['docker', 'node'];

      createComponent({ value: savedOnBackendTags }, { handlers: emptyTagListHandler });
      await waitForPromises();
    });

    it('should have a disabled listbox', () => {
      expect(findTagsList().props('disabled')).toBe(true);
    });
  });

  describe('loading runner tags', () => {
    it.each`
      namespaceTypeValue         | projectQueryCalled | groupQueryCalled
      ${NAMESPACE_TYPES.PROJECT} | ${1}               | ${0}
      ${NAMESPACE_TYPES.GROUP}   | ${0}               | ${1}
    `(
      'should load correct query base on namespaceType',
      ({ namespaceTypeValue, projectQueryCalled, groupQueryCalled }) => {
        createComponent({ namespaceType: namespaceTypeValue });

        expect(handlers.projectRequestHandler).toHaveBeenCalledTimes(projectQueryCalled);
        expect(handlers.groupRequestHandler).toHaveBeenCalledTimes(groupQueryCalled);
      },
    );
  });

  describe('select all option', () => {
    it('should select all tags', async () => {
      await waitForPromises();

      findTagsList().vm.$emit('select-all');

      expect(wrapper.emitted('input')).toEqual([[getUniqueTagListFromEdges(RUNNER_TAG_LIST_MOCK)]]);
    });

    it('should reset all selections', async () => {
      const uniqueTags = getUniqueTagListFromEdges(RUNNER_TAG_LIST_MOCK);

      createComponent({
        value: uniqueTags,
      });
      await waitForPromises();

      uniqueTags.forEach((_, index) => {
        expect(findDropdownItems().at(index).props('isSelected')).toBe(true);
      });

      findTagsList().vm.$emit('reset');
      await nextTick();

      uniqueTags.forEach((_, index) => {
        expect(findDropdownItems().at(index).props('isSelected')).toBe(false);
      });

      expect(wrapper.emitted('input')).toEqual([[[]]]);
    });
  });
});
