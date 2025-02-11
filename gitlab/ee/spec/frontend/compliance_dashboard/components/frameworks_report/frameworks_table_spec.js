import {
  GlLoadingIcon,
  GlSearchBoxByClick,
  GlTable,
  GlLink,
  GlModal,
  GlAlert,
  GlDisclosureDropdown,
} from '@gitlab/ui';
import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';

import { mountExtended } from 'helpers/vue_test_utils_helper';
import { stubComponent } from 'helpers/stub_component';
import {
  createComplianceFrameworksReportResponse,
  createFramework,
} from 'ee_jest/compliance_dashboard/mock_data';
import FrameworksTable from 'ee/compliance_dashboard/components/frameworks_report/frameworks_table.vue';
import FrameworkInfoDrawer from 'ee/compliance_dashboard/components/frameworks_report/framework_info_drawer.vue';
import { ROUTE_EDIT_FRAMEWORK, ROUTE_EXPORT_FRAMEWORK } from 'ee/compliance_dashboard/constants';
import { DOCS_URL_IN_EE_DIR } from 'jh_else_ce/lib/utils/url_utility';
import DeleteModal from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/delete_modal.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import FrameworkBadge from 'ee/compliance_dashboard/components/shared/framework_badge.vue';

Vue.use(VueApollo);

jest.mock('~/lib/utils/axios_utils');

describe('FrameworksTable component', () => {
  let wrapper;
  let $router;
  const $toast = {
    show: jest.fn(),
  };

  const GROUP_PATH = 'group';
  const SUBGROUP_PATH = `${GROUP_PATH}/subgroup`;
  const PROJECTS_TOTAL_COUNT = 50;
  const frameworksResponse = createComplianceFrameworksReportResponse({
    count: 2,
    projects: 2,
    projectsTotalCount: PROJECTS_TOTAL_COUNT,
    groupPath: GROUP_PATH,
  });
  const frameworks = frameworksResponse.data.namespace.complianceFrameworks.nodes;
  const projects = frameworks[0].projects.nodes;
  const rowCheckIndex = 0;
  const modalStub = { show: jest.fn(), hide: jest.fn() };
  const GlModalStub = stubComponent(GlModal, { methods: modalStub });

  const findTable = () => wrapper.findComponent(GlTable);
  const findTableHeaders = () => findTable().findAll('th > div > span');
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findLoadingIcon = () => wrapper.findComponent(GlLoadingIcon);
  const findEmptyState = () => wrapper.findByText('No frameworks found');
  const findTableLinks = (idx) => findTableRow(idx).findAllComponents(GlLink);
  const findFrameworkInfoSidebar = () => wrapper.findComponent(FrameworkInfoDrawer);
  const findSearchBox = () => wrapper.findComponent(GlSearchBoxByClick);
  const findNoFrameworksAlert = () => wrapper.findComponent(GlAlert);
  const findActionsDropdowns = () => wrapper.findAllComponents(GlDisclosureDropdown);
  const findActionsDropdownItems = () => findActionsDropdowns().at(0).findAll('.gl-mx-2');
  const findEditAction = () => wrapper.findByTestId('action-edit');
  const findDeleteAction = () => wrapper.findByTestId('action-delete');
  const findCopyIdAction = () => wrapper.findByTestId('action-copy-id');
  const findDeleteActionTooltip = () => wrapper.findByTestId('delete-tooltip');
  const findDeleteModal = () => wrapper.findComponent(DeleteModal);
  const findBadge = () => wrapper.findComponent(FrameworkBadge);

  const toggleSidebar = async () => {
    findTableRow(rowCheckIndex).trigger('click');
    await nextTick();
  };

  const createComponent = (props = {}, queryParams = {}) => {
    const currentQueryParams = { ...queryParams };
    $router = {
      push: jest.fn().mockImplementation(({ query }) => {
        Object.assign(currentQueryParams, query);
      }),
    };
    return mountExtended(FrameworksTable, {
      propsData: {
        groupPath: GROUP_PATH,
        rootAncestor: {
          path: GROUP_PATH,
          name: 'Group',
          complianceCenterPath: 'group/compliance_dashboard',
        },
        frameworks: [],
        isLoading: true,
        ...props,
      },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      provide: {
        groupSecurityPoliciesPath: '/example-group-security-policies-path',
      },
      mocks: {
        $route: { query: currentQueryParams },
        $router,
        $toast,
      },
      stubs: {
        EditForm: true,
        FrameworkInfoDrawer: true,
        GlModal: GlModalStub,
      },
      attachTo: document.body,
    });
  };

  describe('default behavior', () => {
    it('renders the loading indicator while loading', () => {
      wrapper = createComponent();

      expect(findLoadingIcon().exists()).toBe(true);
      expect(findTable().text()).not.toContain('No frameworks found');
    });

    it('renders the empty state when no frameworks found', () => {
      wrapper = createComponent({ isLoading: false });

      const emptyState = findEmptyState();

      expect(findLoadingIcon().exists()).toBe(false);
      expect(emptyState.exists()).toBe(true);
      expect(emptyState.text()).toBe('No frameworks found');
    });

    it('has the correct table headers for top-level group', () => {
      wrapper = createComponent({ isLoading: false });
      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());

      expect(headerTexts).toStrictEqual([
        'Frameworks',
        'Associated projects',
        'Policies',
        'Action',
      ]);
    });

    it('emits search event when underlying search box is submitted', () => {
      wrapper = createComponent({ isLoading: false });

      findSearchBox().vm.$emit('submit', 'test');
      expect(wrapper.emitted('search').at(-1)).toStrictEqual(['test']);
    });

    it('emits search event with empty value when underlying search box is cleared', () => {
      wrapper = createComponent({ isLoading: false });

      findSearchBox().vm.$emit('clear');
      expect(wrapper.emitted('search').at(-1)).toStrictEqual(['']);
    });
  });

  describe('when projectPath is provided', () => {
    it('has the correct table headers', () => {
      wrapper = createComponent({ isLoading: false, groupPath: null, projectPath: 'foo/bar' });
      const headerTexts = findTableHeaders().wrappers.map((h) => h.text());

      expect(headerTexts).toStrictEqual(['Frameworks', 'Policies', 'Action']);
    });

    it('does not render search bar', () => {
      wrapper = createComponent({ isLoading: false, groupPath: null, projectPath: 'foo/bar' });

      expect(findSearchBox().exists()).toBe(false);
    });
  });

  describe('No frameworks alert', () => {
    it('does not render for a top-level group when there are frameworks', () => {
      wrapper = createComponent({
        isLoading: false,
      });
      expect(findNoFrameworksAlert().exists()).toBe(false);
    });

    it('renders alert with links for a sub group when there are no frameworks', () => {
      const links = () => findNoFrameworksAlert().findAllComponents(GlLink);
      wrapper = createComponent({
        isLoading: false,
        groupPath: SUBGROUP_PATH,
      });
      expect(findNoFrameworksAlert().text()).toMatchInterpolatedText(
        'No frameworks found. Create a framework in top-level group Group. Learn more.',
      );
      expect(links().at(0).attributes('href')).toBe('group/compliance_dashboard');
      expect(links().at(1).attributes('href')).toBe(
        `${DOCS_URL_IN_EE_DIR}/user/group/compliance_frameworks.html#prerequisites`,
      );
    });

    it('does not render for a sub group when there are frameworks', () => {
      wrapper = createComponent({
        frameworks,
        groupPath: SUBGROUP_PATH,
        isLoading: false,
      });
      expect(findNoFrameworksAlert().exists()).toBe(false);
    });
  });

  describe('when there are policies', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it.each(Object.keys(frameworks))('has the correct data for row %s', (idx) => {
      const frameworkPolicies = findTableRowData(idx)
        .wrappers.map((d) => d.text())
        .at(2);
      expect(frameworkPolicies).toMatch(
        [
          ...frameworks[idx].scanExecutionPolicies.nodes,
          ...frameworks[idx].scanResultPolicies.nodes,
          ...frameworks[idx].pipelineExecutionPolicies.nodes,
          ...frameworks[idx].vulnerabilityManagementPolicies.nodes,
        ]
          .map((x) => x.name)
          .join(','),
      );
    });
  });

  describe('when there are projects', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it.each(Object.keys(frameworks))('has the correct data for row %s', (idx) => {
      const [frameworkName, associatedProjects] = findTableRowData(idx).wrappers.map((d) =>
        d.text(),
      );
      expect(frameworkName).toContain(frameworks[idx].name);
      expect(associatedProjects).toContain(projects[idx].name);
      expect(associatedProjects).toContain(`and ${PROJECTS_TOTAL_COUNT - projects.length} more`);
      expect(findTableLinks(idx).wrappers).toHaveLength(2);
      expect(findTableLinks(idx).wrappers.map((w) => w.attributes('href'))).toStrictEqual(
        projects.map((p) => p.webUrl),
      );
    });

    describe('Sidebar', () => {
      describe('edit button in sidebar', () => {
        describe('when query has framework id', () => {
          beforeEach(() => {
            wrapper = createComponent(
              {
                frameworks,
                isLoading: false,
              },
              { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
            );
          });

          it('passes the selected framework as a framework prop', () => {
            expect(findFrameworkInfoSidebar().props('framework')).toMatchObject(
              frameworks[rowCheckIndex],
            );
          });
        });

        describe('when query does not have framework id', () => {
          it('the framework prop is null', () => {
            expect(findFrameworkInfoSidebar().props('framework')).toBe(null);
          });

          it('adds id to the query after sidebar is open', async () => {
            await toggleSidebar();

            expect($router.push).toHaveBeenCalledWith({
              query: { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
            });
          });
        });

        it('opens edit form for the framework', async () => {
          await toggleSidebar();

          await findFrameworkInfoSidebar().vm.$emit('edit', frameworks[rowCheckIndex]);

          expect($router.push).toHaveBeenCalledWith({
            name: ROUTE_EDIT_FRAMEWORK,
            params: { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
          });
        });
      });

      describe('closing the sidebar', () => {
        it('has the correct props when closed', async () => {
          await toggleSidebar();

          await findFrameworkInfoSidebar().vm.$emit('close');

          await nextTick();

          expect(findFrameworkInfoSidebar().props('framework')).toBe(null);
        });

        it('removes query', async () => {
          await toggleSidebar();

          await findFrameworkInfoSidebar().vm.$emit('close');

          expect($router.push).toHaveBeenCalledWith({
            query: null,
          });
        });
      });
    });
  });

  describe('actions dropdown', () => {
    beforeEach(() => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });
    });

    it('renders dropdown with actions for each framework', () => {
      expect(findActionsDropdowns()).toHaveLength(frameworks.length);
      expect(findActionsDropdowns().at(0).props('icon')).toBe('ellipsis_v');
      expect(findActionsDropdowns().at(0).props('toggleText')).toBe(
        "Actions for Auditor's framework 1",
      );
    });

    it('dropdown has four actions', () => {
      expect(findActionsDropdownItems()).toHaveLength(4);
    });

    describe('edit action', () => {
      it('has correct text', () => {
        expect(findEditAction().text()).toBe('Edit');
      });

      it('redirects to edit framework page on action', () => {
        findEditAction().vm.$emit('click');
        expect($router.push).toHaveBeenCalledWith({
          name: ROUTE_EDIT_FRAMEWORK,
          params: { id: getIdFromGraphQLId(frameworks[rowCheckIndex].id) },
        });
      });
    });

    describe('delete action', () => {
      it('renders expected text', () => {
        expect(findDeleteAction().text()).toBe('Delete');
      });

      it('shows delete modal on action', () => {
        findDeleteAction().vm.$emit('click');
        expect(modalStub.show).toHaveBeenCalled();
        findDeleteModal().vm.$emit('delete');
        expect(wrapper.emitted('delete-framework')).toEqual([[frameworks[rowCheckIndex].id]]);
      });

      it('disables delete action and shows correct tooltip when framework is default', async () => {
        const defaultFramework = createFramework({ default: true });
        wrapper = createComponent({
          frameworks: [defaultFramework],
          isLoading: false,
        });

        await nextTick();
        expect(findDeleteAction().props('disabled')).toBe(true);

        const tooltip = getBinding(findDeleteActionTooltip().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(findDeleteActionTooltip().attributes('title')).toBe(
          "Compliance frameworks that are linked to an active policy can't be deleted",
        );
      });

      it('disables delete action and shows correct tooltip when framework has linked policies', async () => {
        const frameworkWithPolicies = createFramework();
        wrapper = createComponent({
          frameworks: [frameworkWithPolicies],
          isLoading: false,
        });

        await nextTick();

        expect(findDeleteAction().props('disabled')).toBe(true);

        const tooltip = getBinding(findDeleteActionTooltip().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(findDeleteActionTooltip().attributes('title')).toBe(
          "Compliance frameworks that are linked to an active policy can't be deleted",
        );
      });

      it('enables delete action when framework is not default and has no linked policies', async () => {
        const frameworkWithoutPolicies = createFramework({
          options: {
            scanResultPolicies: { nodes: [] },
            scanExecutionPolicies: { nodes: [] },
            pipelineExecutionPolicies: { nodes: [] },
            vulnerabilityManagementPolicies: { nodes: [] },
          },
        });
        wrapper = createComponent({
          frameworks: [frameworkWithoutPolicies],
          isLoading: false,
        });

        await nextTick();

        expect(findDeleteAction().props('disabled')).toBe(false);
        expect(findDeleteActionTooltip().attributes('title')).toBe('');
      });
    });

    describe('copy id action', () => {
      it('has expected text', () => {
        expect(findCopyIdAction().text()).toBe('Copy ID: 1');
      });

      it('renders help text', () => {
        const tooltip = getBinding(findCopyIdAction().element, 'gl-tooltip');
        expect(tooltip).toBeDefined();
        expect(findCopyIdAction().attributes('title')).toBe(
          'Use the compliance framework ID in configuration or API requests.',
        );
      });

      it('copies id to clipboard on action', () => {
        jest.spyOn(navigator.clipboard, 'writeText');
        findCopyIdAction().vm.$emit('click');
        expect(navigator.clipboard.writeText).toHaveBeenCalledWith(1);
        expect($toast.show).toHaveBeenCalledWith('Framework ID copied to clipboard.');
      });
    });
  });

  describe('framework badge', () => {
    it('sets popover mode to edit in top-level group', () => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
      });

      expect(findBadge().props('popoverMode')).toBe('edit');
    });

    it('sets popover mode to details in subgroup', () => {
      wrapper = createComponent({
        frameworks,
        isLoading: false,
        groupPath: SUBGROUP_PATH,
      });

      expect(findBadge().props('popoverMode')).toBe('details');
    });
  });

  describe('when opened in a subgroup', () => {
    const subgroupFrameworksResponse = createComplianceFrameworksReportResponse({
      count: 2,
      projects: 2,
      groupPath: GROUP_PATH,
    });
    const subgroupFrameworks = subgroupFrameworksResponse.data.namespace.complianceFrameworks.nodes;
    const subgroupProjects = subgroupFrameworks[0].projects.nodes;
    subgroupProjects[1].fullPath = `${SUBGROUP_PATH}/project1`;

    beforeEach(() => {
      wrapper = createComponent({
        groupPath: SUBGROUP_PATH,
        frameworks: subgroupFrameworks,
        isLoading: false,
      });
    });

    it('does not render associated projects column in subgroup', () => {
      expect(findTableHeaders().wrappers.map((w) => w.text())).not.toContain('Associated projects');
    });

    it('renders only copy id action in action dropdown', () => {
      expect(findActionsDropdownItems()).toHaveLength(1);
      expect(findActionsDropdownItems().at(0).text()).toBe('Copy ID: 1');
    });

    it('sets framework badge popover mode to details', () => {
      expect(findBadge().props('popoverMode')).toBe('details');
    });
  });

  describe('exportFramework', () => {
    const mockFrameworkId = '123';
    const expectedUrl = '/groups/group-path/-/security/compliance_frameworks/123.json';
    let locationMock;

    beforeEach(() => {
      wrapper = createComponent({
        groupPath: 'group-path',
      });

      locationMock = {
        href: 'http://test.host/',
      };

      jest.spyOn(window, 'location', 'get').mockImplementation(() => locationMock);

      jest.clearAllMocks();
    });

    it('redirects to framework export URL when export succeeds', async () => {
      const framework = { id: mockFrameworkId };
      const resolvedRoute = { href: expectedUrl };

      $router.resolve = jest.fn().mockReturnValue(resolvedRoute);

      await wrapper.vm.exportFramework(framework);

      expect($router.resolve).toHaveBeenCalledWith({
        name: ROUTE_EXPORT_FRAMEWORK,
        params: { id: getIdFromGraphQLId(mockFrameworkId) },
      });
      expect(locationMock.href).toBe(expectedUrl);
    });

    it('shows error toast when export fails', async () => {
      const error = new Error('Export failed');
      const toastSpy = jest.spyOn(wrapper.vm.$toast, 'show');

      $router.resolve = jest.fn().mockImplementation(() => {
        throw error;
      });

      await wrapper.vm.exportFramework({ id: mockFrameworkId });

      expect(toastSpy).toHaveBeenCalledWith('Failed to export framework');
    });
  });
});
