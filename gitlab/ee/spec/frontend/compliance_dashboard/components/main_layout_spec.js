import { mount } from '@vue/test-utils';
import { GlTabs, GlTooltip, GlLink } from '@gitlab/ui';
import { extendedWrapper, shallowMountExtended } from 'helpers/vue_test_utils_helper';

import MainLayout from 'ee/compliance_dashboard/components/main_layout.vue';
import PageHeading from '~/vue_shared/components/page_heading.vue';
import { helpPagePath } from '~/helpers/help_page_helper';
import { stubComponent } from 'helpers/stub_component';
import { mockTracking } from 'helpers/tracking_helper';
import {
  ROUTE_STANDARDS_ADHERENCE,
  ROUTE_FRAMEWORKS,
  ROUTE_PROJECTS,
  ROUTE_VIOLATIONS,
  ROUTE_NEW_FRAMEWORK,
} from 'ee/compliance_dashboard/constants';

describe('ComplianceReportsApp component', () => {
  let wrapper;
  let trackingSpy;
  const $router = { push: jest.fn() };
  const defaultInjects = {
    mergeCommitsCsvExportPath: '/csv',
    projectFrameworksCsvExportPath: '/project_frameworks_report.csv',
    violationsCsvExportPath: '/compliance_violation_reports.csv',
    adherencesCsvExportPath: '/compliance_standards_adherences.csv',
    frameworksCsvExportPath: '/compliance_frameworks_report.csv',
    glAbilities: {
      adminComplianceFramework: true,
    },
  };

  const groupPath = 'top-level-group-path';
  const rootAncestor = {
    path: 'top-level-group-path',
    name: 'Top Level Group',
    complianceCenterPath: 'top-level-group-path/compliance-center-path',
  };

  const findHeader = () => wrapper.findComponent(PageHeading);
  const findExportDropdown = () => wrapper.findByText('Export');
  const findMergeCommitsExportButton = () => wrapper.findByText('Export chain of custody report');
  const findViolationsExportButton = () => wrapper.findByText('Export violations report');
  const findAdherencesExportButton = () => wrapper.findByText('Export standards adherence report');
  const findFrameworksExportButton = () => wrapper.findByText('Export frameworks report');
  const findProjectFrameworksExportButton = () =>
    wrapper.findByText('Export list of project frameworks');
  const findTabs = () => wrapper.findComponent(GlTabs);
  const findProjectsTab = () => wrapper.findByTestId('projects-tab-content');
  const findProjectFrameworksTab = () => wrapper.findByTestId('frameworks-tab-content');
  const findViolationsTab = () => wrapper.findByTestId('violations-tab-content');
  const findStandardsAdherenceTab = () => wrapper.findByTestId('standards-adherence-tab-content');
  const findNewFrameworkButton = () => wrapper.findByRole('button', { name: 'New framework' });
  const findNewFrameworkTooltip = () => wrapper.findComponent(GlTooltip);

  const createComponent = (
    mountFn = shallowMountExtended,
    mocks = {},
    provide = {},
    props = {},
    // eslint-disable-next-line max-params
  ) => {
    return extendedWrapper(
      mountFn(MainLayout, {
        mocks: {
          $router,
          $route: {
            name: ROUTE_VIOLATIONS,
          },
          ...mocks,
        },
        propsData: {
          availableTabs: [
            ROUTE_STANDARDS_ADHERENCE,
            ROUTE_VIOLATIONS,
            ROUTE_PROJECTS,
            ROUTE_FRAMEWORKS,
          ],
          groupPath,
          rootAncestor,
          ...props,
        },
        stubs: {
          'router-view': stubComponent({}),
        },
        provide: {
          ...defaultInjects,
          ...provide,
        },
      }),
    );
  };

  describe('adherence standards report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount);
    });

    it('renders the standards adherence report tab', () => {
      expect(findStandardsAdherenceTab().exists()).toBe(true);
    });

    it('renders the adherences export button', () => {
      expect(findAdherencesExportButton().exists()).toBe(true);
    });

    it('does not render the adherences export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { adherencesCsvExportPath: null });
      expect(findAdherencesExportButton().exists()).toBe(false);
    });
  });

  describe('New framework button', () => {
    it('navigates to add framework page when in top level group', () => {
      wrapper = createComponent(mount);

      findNewFrameworkButton().trigger('click');
      expect($router.push).toHaveBeenCalledWith({ name: ROUTE_NEW_FRAMEWORK });
    });

    it('is disabled and shows info tooltip otherwise', () => {
      wrapper = createComponent(mount, {}, {}, { groupPath: 'sub-group-path' });

      expect(findNewFrameworkButton().attributes('disabled')).toBeDefined();
      expect(findNewFrameworkTooltip().text()).toMatchInterpolatedText(
        'You can only create the compliance framework in top-level group Top Level Group',
      );
    });

    describe('when ability `adminComplianceFramework` is false', () => {
      it('does not render the button', () => {
        wrapper = createComponent(
          mount,
          {},
          { glAbilities: { adminComplianceFramework: false } },
          {},
        );

        expect(findNewFrameworkButton().exists()).toBe(false);
      });
    });
  });

  describe('violations report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount);
    });

    it('renders the violations report tab', () => {
      expect(findViolationsTab().exists()).toBe(true);
    });

    it('passes the expected values to the header', () => {
      expect(findHeader().props('heading')).toBe('Compliance center');
      expect(findHeader().text()).toContain(
        'Report and manage standards adherence, violations, and compliance frameworks for the group. Learn more.',
      );
      expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
        helpPagePath('user/compliance/compliance_center/_index.md'),
      );
    });

    it('renders the violations export button', () => {
      expect(findViolationsExportButton().exists()).toBe(true);
    });

    it('does not render the merge commit export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { mergeCommitsCsvExportPath: null });
      findTabs().vm.$emit('input', 0);

      expect(findMergeCommitsExportButton().exists()).toBe(false);
    });

    it('does not render the violations export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { violationsCsvExportPath: null });
      findTabs().vm.$emit('input', 0);

      expect(findViolationsExportButton().exists()).toBe(false);
    });
  });

  describe('projects report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_PROJECTS,
        },
      });
    });

    it('renders the projects report tab', () => {
      expect(findProjectsTab().exists()).toBe(true);
    });

    it('passes the expected values to the header', () => {
      expect(findHeader().props('heading')).toBe('Compliance center');
      expect(findHeader().text()).toContain(
        'Report and manage standards adherence, violations, and compliance frameworks for the group. Learn more.',
      );
      expect(wrapper.findComponent(GlLink).attributes('href')).toBe(
        helpPagePath('user/compliance/compliance_center/_index.md'),
      );
    });

    it('renders the project frameworks export button', () => {
      expect(findProjectFrameworksExportButton().exists()).toBe(true);
    });

    it('does not render the projects export button when there is no CSV path', () => {
      wrapper = createComponent(
        mount,
        {
          $route: {
            name: ROUTE_FRAMEWORKS,
          },
        },
        { projectFrameworksCsvExportPath: null },
      );

      expect(findProjectFrameworksExportButton().exists()).toBe(false);
    });
  });

  describe('frameworks report', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_PROJECTS,
        },
      });
    });

    it('renders the projects tab', () => {
      expect(findProjectsTab().exists()).toBe(true);
    });

    it('renders the frameworks report tab', () => {
      expect(findProjectFrameworksTab().exists()).toBe(true);
    });

    it('renders the frameworks export button', () => {
      expect(findFrameworksExportButton().exists()).toBe(true);
    });

    it('does not render the adherences export button when there is no CSV path', () => {
      wrapper = createComponent(mount, {}, { frameworksCsvExportPath: null });
      expect(findFrameworksExportButton().exists()).toBe(false);
    });
  });

  it('does not render export button if no report is available', () => {
    wrapper = createComponent(
      mount,
      {},
      {
        projectFrameworksCsvExportPath: null,
        mergeCommitsCsvExportPath: null,
        violationsCsvExportPath: null,
        adherencesCsvExportPath: null,
        frameworksCsvExportPath: null,
      },
    );

    expect(findExportDropdown().exists()).toBe(false);
  });

  describe.each`
    route                        | finder
    ${ROUTE_STANDARDS_ADHERENCE} | ${findStandardsAdherenceTab}
    ${ROUTE_VIOLATIONS}          | ${findViolationsTab}
    ${ROUTE_PROJECTS}            | ${findProjectsTab}
    ${ROUTE_FRAMEWORKS}          | ${findProjectFrameworksTab}
  `('for $route', ({ route, finder }) => {
    const allTabs = [ROUTE_STANDARDS_ADHERENCE, ROUTE_VIOLATIONS, ROUTE_PROJECTS, ROUTE_FRAMEWORKS];
    it('does not render the tab when relevant tab is not passed', () => {
      wrapper = createComponent(
        mount,
        {},
        {},
        {
          availableTabs: allTabs.filter((r) => r !== route),
        },
      );

      expect(finder().exists()).toBe(false);
    });

    it('render the tab when relevant tab is passed', () => {
      wrapper = createComponent(
        mount,
        {},
        {},
        {
          availableTabs: [route],
        },
      );

      expect(finder().exists()).toBe(true);
    });
  });

  describe('tracking', () => {
    beforeEach(() => {
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_VIOLATIONS,
        },
      });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
    });

    it('tracks clicks on framework tab', () => {
      findProjectFrameworksTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'frameworks',
      });
    });
    it('tracks clicks on projects tab', () => {
      findProjectsTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'projects',
      });
    });
    it('tracks clicks on adherence tab', () => {
      findStandardsAdherenceTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'standards_adherence',
      });
    });
    it('tracks clicks on violations tab', () => {
      // Can't navigate to a page we are already on so use a different tab to start with
      wrapper = createComponent(mount, {
        $route: {
          name: ROUTE_FRAMEWORKS,
        },
      });
      trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
      findViolationsTab().vm.$emit('click');

      expect(trackingSpy).toHaveBeenCalledTimes(1);
      expect(trackingSpy).toHaveBeenCalledWith(undefined, 'click_report_tab', {
        label: 'violations',
      });
    });
  });
});
