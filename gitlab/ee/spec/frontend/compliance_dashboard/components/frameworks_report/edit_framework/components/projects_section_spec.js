import { GlTable, GlLink } from '@gitlab/ui';

import ProjectsSection from 'ee/compliance_dashboard/components/frameworks_report/edit_framework/components/projects_section.vue';
import VisibilityIconButton from '~/vue_shared/components/visibility_icon_button.vue';

import { mountExtended } from 'helpers/vue_test_utils_helper';

import { createFramework } from '../../../../mock_data';

describe('Projects section', () => {
  let wrapper;

  const framework = createFramework({ id: 1, projects: 3 });
  const projects = framework.projects.nodes;
  const findTable = () => wrapper.findComponent(GlTable);
  const findTableRow = (idx) => findTable().findAll('tbody > tr').at(idx);
  const findTableRowData = (idx) => findTableRow(idx).findAll('td');
  const findInfoText = () => wrapper.findByTestId('info-text');
  const findLink = () => findInfoText().findComponent(GlLink);
  const projectLinks = () => wrapper.findAllByTestId('project-link');
  const subgroupLinks = () => wrapper.findAllByTestId('subgroup-link');

  const createComponent = () => {
    wrapper = mountExtended(ProjectsSection, {
      propsData: {
        complianceFramework: framework,
      },
    });
  };

  describe('when loaded', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders title', () => {
      const title = wrapper.findByText('Projects');
      expect(title.exists()).toBe(true);
    });

    it('correctly displays description', () => {
      const description = wrapper.findByText(
        'All selected projects will be covered by the framework’s selected requirements and the policies.',
      );
      expect(description.exists()).toBe(true);
    });

    it('correctly calculates projects', () => {
      const { items } = findTable().vm.$attrs;
      expect(items).toHaveLength(3);
    });

    it.each(Object.keys(projects))('has the correct data for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d.text());

      expect(frameworkProjects[0]).toMatch(projects[idx].name);
      expect(frameworkProjects[1]).toMatch(projects[idx].namespace.fullName);
      expect(frameworkProjects[2]).toMatch(projects[idx].description);
    });

    it.each(Object.keys(projects))('has the correct visibility icon for row %s', (idx) => {
      const frameworkProjects = findTableRowData(idx).wrappers.map((d) => d);

      const visibilityIcon = frameworkProjects[0].findComponent(VisibilityIconButton);
      expect(visibilityIcon.props('visibilityLevel')).toMatch(projects[idx].visibility);
    });

    it.each(Object.keys(projects))('renders correct url for the projects %s', (idx) => {
      expect(projectLinks().at(idx).attributes('href')).toBe(projects[idx].webUrl);
    });

    it.each(Object.keys(projects))('renders correct url for the projects subgroup %s', (idx) => {
      expect(subgroupLinks().at(idx).attributes('href')).toBe(projects[idx].namespace.webUrl);
    });

    it('renders information text with correct action', () => {
      expect(findInfoText().text()).toMatchInterpolatedText(
        'Go to the compliance center / project page to apply projects for this framework.',
      );
    });

    it('renders correct atrributes for the info link', () => {
      expect(findLink().attributes('to')).toBe('/projects');
      expect(findLink().attributes('href')).toBe('/projects');
    });
  });
});
