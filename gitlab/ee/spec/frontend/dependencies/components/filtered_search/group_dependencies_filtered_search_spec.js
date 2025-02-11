import { shallowMount } from '@vue/test-utils';
import { GlPopover, GlSprintf } from '@gitlab/ui';
import GroupDependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/group_dependencies_filtered_search.vue';
import DependenciesFilteredSearch from 'ee/dependencies/components/filtered_search/dependencies_filtered_search.vue';
import LicenseToken from 'ee/dependencies/components/filtered_search/tokens/license_token.vue';
import ProjectToken from 'ee/dependencies/components/filtered_search/tokens/project_token.vue';
import PackagerToken from 'ee/dependencies/components/filtered_search/tokens/package_manager_token.vue';
import ComponentToken from 'ee/dependencies/components/filtered_search/tokens/component_token.vue';

describe('GroupDependenciesFilteredSearch', () => {
  let wrapper;

  const defaultProps = {
    tokens: [],
    filteredSearchId: 'group-level-filtered-search',
  };

  const createComponent = ({ provide = {} } = {}) => {
    wrapper = shallowMount(GroupDependenciesFilteredSearch, {
      provide: {
        belowGroupLimit: true,
        glFeatures: {
          groupLevelDependenciesFilteringByPackager: true,
        },
        ...provide,
      },
      stubs: {
        GlSprintf,
      },
    });
  };

  const findDependenciesFilteredSearch = () => wrapper.findComponent(DependenciesFilteredSearch);
  const findPopover = () => wrapper.findComponent(GlPopover);

  describe('when sub-group limit-count is not reached', () => {
    beforeEach(createComponent);

    it('sets the filtered search id', () => {
      expect(findDependenciesFilteredSearch().props('filteredSearchId')).toEqual(
        'group-level-filtered-search',
      );
    });

    it('does not set the filtered-search to be view-only', () => {
      expect(findDependenciesFilteredSearch().props('viewOnly')).toBe(false);
    });

    it('does not show a popover', () => {
      expect(findPopover().exists()).toBe(false);
    });

    it.each`
      tokenTitle     | tokenConfig
      ${'License'}   | ${{ title: 'License', type: 'licenses', multiSelect: true, token: LicenseToken }}
      ${'Project'}   | ${{ title: 'Project', type: 'project_ids', multiSelect: true, token: ProjectToken }}
      ${'Packager'}  | ${{ title: 'Packager', type: 'package_managers', multiSelect: true, token: PackagerToken }}
      ${'Component'} | ${{ title: 'Component', type: 'component_names', multiSelect: true, token: ComponentToken }}
    `('contains a "$tokenTitle" search token', ({ tokenConfig }) => {
      expect(findDependenciesFilteredSearch().props('tokens')).toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            ...tokenConfig,
          }),
        ]),
      );
    });
  });

  describe('when group_leven_dependencies_filtering_by_packager feature flag is disabled', () => {
    it('does not contain a "Packager" search token when the feature flag is not enabled', () => {
      createComponent({
        provide: {
          belowGroupLimit: true,
          glFeatures: { groupLevelDependenciesFilteringByPackager: false },
        },
      });

      expect(findDependenciesFilteredSearch().props('tokens')).not.toMatchObject(
        expect.arrayContaining([
          expect.objectContaining({
            title: 'Packager',
            type: 'package_managers',
            multiSelect: true,
            token: PackagerToken,
          }),
        ]),
      );
    });
  });

  describe('when sub-group limit-count is reached', () => {
    beforeEach(() => {
      createComponent({
        provide: {
          belowGroupLimit: false,
        },
      });
    });

    it('sets the filtered-search to be view-only', () => {
      expect(findDependenciesFilteredSearch().props('viewOnly')).toBe(true);
    });

    it('when hovering over the filtered-search it shows a popover', () => {
      const { filteredSearchId } = defaultProps;

      expect(findPopover().props()).toMatchObject({
        target: filteredSearchId,
      });
    });

    it('shows the correct message in the popover', () => {
      expect(findPopover().props('title')).toBe('Filtering unavailable');
      expect(findPopover().text()).toContain(
        "This group exceeds the maximum number of 600 sub-groups. We cannot accurately filter or search the dependency list above this maximum. To view or filter a subset of this information, go to a subgroup's dependency list.",
      );
    });
  });
});
