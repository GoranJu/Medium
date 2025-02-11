import { GlEmptyState, GlLoadingIcon, GlLink } from '@gitlab/ui';
import MockAdapter from 'axios-mock-adapter';
import { mount } from '@vue/test-utils';
import { nextTick } from 'vue';
import { extendedWrapper } from 'helpers/vue_test_utils_helper';
import DependenciesApp from 'ee/dependencies/components/app.vue';
import DependenciesActions from 'ee/dependencies/components/dependencies_actions.vue';
import SbomReportsErrorsAlert from 'ee/dependencies/components/sbom_reports_errors_alert.vue';
import PaginatedDependenciesTable from 'ee/dependencies/components/paginated_dependencies_table.vue';
import createStore from 'ee/dependencies/store';
import { DEPENDENCY_LIST_TYPES } from 'ee/dependencies/store/constants';
import {
  NAMESPACE_GROUP,
  NAMESPACE_ORGANIZATION,
  NAMESPACE_PROJECT,
} from 'ee/dependencies/constants';
import { TEST_HOST } from 'helpers/test_constants';
import { getDateInPast } from '~/lib/utils/datetime_utility';
import axios from '~/lib/utils/axios_utils';

describe('DependenciesApp component', () => {
  let store;
  let wrapper;
  let mock;

  const { namespace: allNamespace } = DEPENDENCY_LIST_TYPES.all;

  const basicAppProvides = {
    hasDependencies: true,
    endpoint: '/foo',
    exportEndpoint: '/bar',
    emptyStateSvgPath: '/bar.svg',
    documentationPath: TEST_HOST,
    pageInfo: {},
    namespaceType: 'project',
    vulnerabilitiesEndpoint: `/vulnerabilities`,
    latestSuccessfulScanPath: '/group/project/-/pipelines/1',
    scanFinishedAt: getDateInPast(new Date(), 7),
    glFeatures: {
      asynchronousDependencyExportDeliveryForProjects: true,
      asynchronousDependencyExportDeliveryForGroups: true,
    },
  };

  const basicProps = {
    sbomReportsErrors: [],
  };

  const factory = ({ provide, props } = {}) => {
    store = createStore();
    jest.spyOn(store, 'dispatch').mockImplementation();

    const stubs = Object.keys(DependenciesApp.components).filter((name) => name !== 'GlSprintf');

    wrapper = extendedWrapper(
      mount(DependenciesApp, {
        store,
        stubs,
        provide: { ...basicAppProvides, ...provide },
        propsData: { ...basicProps, ...props },
      }),
    );
  };

  const setStateLoaded = () => {
    const total = 2;
    Object.assign(store.state[allNamespace], {
      initialized: true,
      isLoading: false,
      dependencies: Array(total)
        .fill(null)
        .map((_, id) => ({ id })),
    });
    store.state[allNamespace].pageInfo.total = total;
  };

  const findDependenciesTables = () => wrapper.findAllComponents(PaginatedDependenciesTable);

  const findHeader = () => wrapper.find('section > header');
  const findExportButton = () => wrapper.findByTestId('export');
  const findHeaderHelpLink = () => findHeader().findComponent(GlLink);
  const findHeaderScanLink = () => wrapper.findComponent({ ref: 'scanLink' });
  const findTimeAgoMessage = () => wrapper.findByTestId('time-ago-message');

  const expectComponentWithProps = (Component, props = {}) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.isVisible()).toBe(true);
    expect(componentWrapper.props()).toEqual(expect.objectContaining(props));
  };

  const expectComponentPropsToMatchSnapshot = (Component) => {
    const componentWrapper = wrapper.findComponent(Component);
    expect(componentWrapper.props()).toMatchSnapshot();
  };

  const expectNoDependenciesTables = () => expect(findDependenciesTables()).toHaveLength(0);
  const expectNoHeader = () => expect(findHeader().exists()).toBe(false);

  const expectEmptyStateDescription = () => {
    expect(wrapper.html()).toContain(
      'The dependency list details information about the components used within your project.',
    );
  };

  const expectEmptyStateLink = () => {
    const emptyStateLink = wrapper.findComponent(GlLink);
    expect(emptyStateLink.html()).toContain('More Information');
    expect(emptyStateLink.attributes('href')).toBe(TEST_HOST);
    expect(emptyStateLink.attributes('target')).toBe('_blank');
  };

  const expectDependenciesTable = () => {
    const tables = findDependenciesTables();
    expect(tables).toHaveLength(1);
    expect(tables.at(0).props()).toEqual({ namespace: allNamespace });
  };

  const expectHeader = () => {
    expect(findHeader().exists()).toBe(true);
  };

  describe('asyncExport', () => {
    describe.each`
      namespaceType             | projectFlag | groupFlag | result
      ${NAMESPACE_PROJECT}      | ${true}     | ${false}  | ${true}
      ${NAMESPACE_PROJECT}      | ${false}    | ${true}   | ${false}
      ${NAMESPACE_PROJECT}      | ${false}    | ${false}  | ${false}
      ${NAMESPACE_GROUP}        | ${true}     | ${false}  | ${false}
      ${NAMESPACE_GROUP}        | ${false}    | ${true}   | ${true}
      ${NAMESPACE_GROUP}        | ${false}    | ${false}  | ${false}
      ${NAMESPACE_ORGANIZATION} | ${true}     | ${true}   | ${false}
    `('feature flag logic', ({ namespaceType, projectFlag, groupFlag, result }) => {
      beforeEach(() => {
        factory({
          provide: {
            namespaceType,
            glFeatures: {
              asynchronousDependencyExportDeliveryForProjects: projectFlag,
              asynchronousDependencyExportDeliveryForGroups: groupFlag,
            },
          },
        });
      });

      it('sets correct value for asyncExport', () => {
        expect(store.dispatch.mock.calls).toEqual(
          expect.arrayContaining([['setAsyncExport', result]]),
        );
      });
    });
  });

  describe('on creation', () => {
    beforeEach(() => {
      mock = new MockAdapter(axios);
      factory();
    });

    afterEach(() => {
      mock.restore();
    });

    it('dispatches the correct initial actions', () => {
      expect(store.dispatch.mock.calls).toEqual([
        ['setDependenciesEndpoint', basicAppProvides.endpoint],
        ['setExportDependenciesEndpoint', basicAppProvides.exportEndpoint],
        ['setNamespaceType', basicAppProvides.namespaceType],
        ['setPageInfo', expect.anything()],
        ['setSortField', 'severity'],
        ['setAsyncExport', true],
      ]);
    });

    describe('without export endpoint', () => {
      beforeEach(async () => {
        factory({ provide: { exportEndpoint: null } });
        setStateLoaded();

        await nextTick();
      });

      it('removes the export button', () => {
        expect(findExportButton().exists()).toBe(false);
      });
    });

    describe('with namespaceType set to organization', () => {
      beforeEach(async () => {
        factory({
          provide: { namespaceType: NAMESPACE_ORGANIZATION },
        });
        setStateLoaded();
        await nextTick();
      });

      it('removes the actions bar', () => {
        expect(wrapper.findComponent(DependenciesActions).exists()).toBe(false);
      });
    });

    describe('with namespaceType set to group', () => {
      beforeEach(() => {
        factory({ provide: { namespaceType: 'group' } });
      });

      it('dispatches setSortField with severity', () => {
        expect(store.dispatch.mock.calls).toEqual(
          expect.arrayContaining([['setSortField', 'severity']]),
        );
      });
    });

    it('shows only the loading icon', () => {
      expectComponentWithProps(GlLoadingIcon);
      expectNoHeader();
      expectNoDependenciesTables();
    });

    describe('if project has no dependencies', () => {
      beforeEach(async () => {
        factory({ provide: { hasDependencies: false } });
        setStateLoaded();

        await nextTick();
      });

      it('shows only the empty state', () => {
        expectComponentWithProps(GlEmptyState, { svgPath: basicAppProvides.emptyStateSvgPath });
        expectComponentPropsToMatchSnapshot(GlEmptyState);
        expectEmptyStateDescription();
        expectEmptyStateLink();
        expectNoHeader();
        expectNoDependenciesTables();
      });
    });

    describe('given a list of dependencies and ok report', () => {
      beforeEach(async () => {
        setStateLoaded();

        await nextTick();
      });

      it('shows the dependencies table with the correct props', () => {
        expectHeader();
        expectDependenciesTable();
      });

      describe('export functionality', () => {
        it('has a button to perform an async export of the dependency list', () => {
          expect(findExportButton().attributes('icon')).toBe('export');

          findExportButton().vm.$emit('click');

          expect(store.dispatch).toHaveBeenCalledWith(`${allNamespace}/fetchExport`);
        });

        describe.each`
          namespaceType             | expectedTooltip
          ${NAMESPACE_ORGANIZATION} | ${'Export as CSV'}
          ${NAMESPACE_PROJECT}      | ${'Export as JSON'}
          ${NAMESPACE_GROUP}        | ${'Export as JSON'}
        `('with namespaceType set to $namespaceType', ({ namespaceType, expectedTooltip }) => {
          beforeEach(async () => {
            factory({
              provide: { namespaceType },
            });
            setStateLoaded();
            await nextTick();
          });

          it('shows a tooltip for a CSV export', () => {
            expect(findExportButton().attributes('title')).toBe(expectedTooltip);
          });
        });

        describe('with fetching in progress', () => {
          beforeEach(() => {
            store.state[allNamespace].fetchingInProgress = true;
          });

          it('sets the icon to match the loading icon', () => {
            expect(findExportButton().attributes()).toMatchObject({
              icon: '',
              loading: 'true',
            });
          });
        });
      });

      describe('with namespaceType set to group', () => {
        beforeEach(async () => {
          factory({ provide: { namespaceType: 'group' } });

          await nextTick();
        });

        it('does not show a link to the latest scan', () => {
          expect(findHeaderScanLink().exists()).toBe(false);
        });

        it('does not show when the last scan ran', () => {
          expect(findTimeAgoMessage().exists()).toBe(false);
        });
      });

      it('shows a link to the latest scan', () => {
        expect(findHeaderScanLink().attributes('href')).toBe('/group/project/-/pipelines/1');
      });

      it('shows when the last scan ran', () => {
        expect(findTimeAgoMessage().text()).toBe('• 1 week ago');
      });

      it('shows a link to the dependencies documentation page', () => {
        expect(findHeaderHelpLink().attributes('href')).toBe(TEST_HOST);
      });

      it('passes the correct namespace to dependencies actions component', () => {
        expectComponentWithProps(DependenciesActions, { namespace: allNamespace });
      });

      describe('where there is no pipeline info', () => {
        beforeEach(async () => {
          factory({
            provide: {
              latestSuccessfulScanPath: null,
              scanFinishedAt: null,
            },
          });
          setStateLoaded();

          await nextTick();
        });

        it('shows the header', () => {
          expectHeader();
        });

        it('does not show when the last scan ran', () => {
          expect(findHeader().text()).not.toContain('1 week ago');
        });

        it('does not show a link to the latest scan', () => {
          expect(findHeaderScanLink().exists()).toBe(false);
        });
      });
    });

    describe('given SBOM report errors are present', () => {
      const sbomErrors = [['Invalid SBOM report']];

      beforeEach(async () => {
        factory({
          props: { sbomReportsErrors: sbomErrors },
        });
        setStateLoaded();

        await nextTick();
      });

      it('passes the correct props to the sbom-report-errort alert', () => {
        expectComponentWithProps(SbomReportsErrorsAlert, {
          errors: sbomErrors,
        });
      });

      it('shows the dependencies table with the correct props', expectDependenciesTable);
    });
  });
});
