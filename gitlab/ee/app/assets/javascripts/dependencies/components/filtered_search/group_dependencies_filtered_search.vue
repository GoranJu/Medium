<script>
import { GlLink, GlPopover, GlSprintf } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { OPERATORS_IS } from '~/vue_shared/components/filtered_search_bar/constants';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import LicenseToken from './tokens/license_token.vue';
import ProjectToken from './tokens/project_token.vue';
import ComponentToken from './tokens/component_token.vue';
import PackagerToken from './tokens/package_manager_token.vue';
import DependenciesFilteredSearch from './dependencies_filtered_search.vue';

export default {
  components: {
    GlPopover,
    GlLink,
    GlSprintf,
    DependenciesFilteredSearch,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['belowGroupLimit'],
  computed: {
    viewOnly() {
      return !this.belowGroupLimit;
    },
    tokens() {
      return [
        {
          type: 'licenses',
          title: __('License'),
          multiSelect: true,
          unique: true,
          token: LicenseToken,
          operators: OPERATORS_IS,
        },
        {
          type: 'project_ids',
          title: __('Project'),
          multiSelect: true,
          unique: true,
          token: ProjectToken,
          operators: OPERATORS_IS,
        },
        {
          type: 'component_names',
          title: __('Component'),
          multiSelect: true,
          unique: true,
          token: ComponentToken,
          operators: OPERATORS_IS,
        },
        ...(this.glFeatures.groupLevelDependenciesFilteringByPackager
          ? [
              {
                type: 'package_managers',
                title: __('Packager'),
                multiSelect: true,
                unique: true,
                token: PackagerToken,
                operators: OPERATORS_IS,
              },
            ]
          : []),
      ];
    },
  },
  GROUP_LEVEL_DEPENDENCY_LIST_DOC: helpPagePath('user/application_security/dependency_list/_index'),
  i18n: {
    popoverTitle: s__('Dependencies|Filtering unavailable'),
    description: s__(
      `Dependencies|This group exceeds the maximum number of 600 sub-groups. We cannot accurately filter or search the dependency list above this maximum. To view or filter a subset of this information, go to a subgroup's dependency list.`,
    ),
  },
  filteredSearchId: 'group-level-filtered-search',
};
</script>

<template>
  <div>
    <dependencies-filtered-search
      :view-only="viewOnly"
      :tokens="tokens"
      :filtered-search-id="$options.filteredSearchId"
    />
    <gl-popover
      v-if="!belowGroupLimit"
      :target="$options.filteredSearchId"
      :title="$options.i18n.popoverTitle"
      triggers="hover"
      :show-close-button="true"
      container="viewport"
    >
      <gl-sprintf :message="$options.i18n.description">
        <template #link="{ content }">
          <gl-link :href="$options.GROUP_LEVEL_DEPENDENCY_LIST_DOC" class="gl-text-sm">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </gl-popover>
  </div>
</template>
