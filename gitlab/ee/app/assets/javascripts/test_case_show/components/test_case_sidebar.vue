<script>
import { s__ } from '~/locale';
import ProjectSelect from '~/sidebar/components/move/issuable_move_dropdown.vue';
import LabelsSelectWidget from '~/sidebar/components/labels/labels_select_widget/labels_select_root.vue';
import SidebarConfidentialityWidget from '~/sidebar/components/confidential/sidebar_confidentiality_widget.vue';
import { TYPE_TEST_CASE, WORKSPACE_PROJECT } from '~/issues/constants';
import TestCaseGraphQL from '../mixins/test_case_graphql';

export default {
  TYPE_TEST_CASE,
  WORKSPACE_PROJECT,
  components: {
    ProjectSelect,
    LabelsSelectWidget,
    SidebarConfidentialityWidget,
  },
  mixins: [TestCaseGraphQL],
  inject: [
    'projectFullPath',
    'testCaseId',
    'canEditTestCase',
    'canMoveTestCase',
    'labelsFetchPath',
    'labelsManagePath',
    'projectsFetchPath',
    'testCasesPath',
  ],
  props: {
    sidebarExpanded: {
      type: Boolean,
      required: true,
    },
    selectedLabels: {
      type: Array,
      required: true,
    },
    moved: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      sidebarExpandedOnClick: false,
      testCaseLabelsSelectInProgress: false,
    };
  },
  computed: {
    selectProjectDropdownButtonTitle() {
      return this.testCaseMoveInProgress
        ? s__('TestCases|Moving test case')
        : s__('TestCases|Move test case');
    },
  },
  mounted() {
    this.sidebarEl = document.querySelector('aside.right-sidebar');
  },
  methods: {
    toggleSidebar() {
      this.$emit('sidebar-toggle');
    },
    expandSidebar() {
      this.toggleSidebar();
      this.sidebarExpandedOnClick = true;
    },
    closeSidebar() {
      this.sidebarExpandedOnClick = false;
      this.toggleSidebar();
    },
    expandSidebarAndOpenDropdown(dropdownButtonSelector) {
      // Expand the sidebar if not already expanded.
      if (!this.sidebarExpanded) {
        this.expandSidebar();
      }

      this.$nextTick(() => {
        // Wait for sidebar expand animation to complete
        // before revealing the dropdown.
        this.sidebarEl.addEventListener(
          'transitionend',
          () => {
            document
              .querySelector(dropdownButtonSelector)
              .dispatchEvent(new Event('click', { bubbles: true, cancelable: false }));
          },
          { once: true },
        );
      });
    },
    handleSidebarDropdownClose() {
      if (this.sidebarExpandedOnClick) {
        this.closeSidebar();
      }
    },
    handleLabelsCollapsedButtonClick() {
      if (!this.sidebarExpanded) {
        this.expandSidebar();
      } else if (this.sidebarExpandedOnClick) {
        this.closeSidebar();
      }
    },
    handleProjectsCollapsedButtonClick() {
      this.expandSidebarAndOpenDropdown('.js-issuable-move-block .js-sidebar-dropdown-toggle');
    },
    handleUpdateSelectedLabels(labels) {
      // Iterate over selection and check if labels which were
      // either selected or removed aren't leading to same selection
      // as current one, as then we don't want to make network call
      // since nothing has changed.
      const anyLabelUpdated = labels.some((label) => {
        // Find this label in existing selection.
        const existingLabel = this.selectedLabels.find((l) => l.id === label.id);

        // Check either of the two following conditions;
        // 1. A label that's not currently applied is being applied.
        // 2. A label that's already applied is being removed.
        return (!existingLabel && label.set) || (existingLabel && !label.set);
      });

      // Only proceed with action if there are any label updates to be done.
      if (anyLabelUpdated) {
        this.testCaseLabelsSelectInProgress = true;

        return this.updateTestCase({
          variables: {
            addLabelIds: labels.filter((label) => label.set).map((label) => label.id),
            removeLabelIds: labels.filter((label) => !label.set).map((label) => label.id),
          },
          errorMessage: s__('TestCases|Something went wrong while updating the test case labels.'),
        })
          .then((updatedTestCase) => {
            this.$emit('test-case-updated', updatedTestCase);
          })
          .finally(() => {
            this.testCaseLabelsSelectInProgress = false;
          });
      }
      return null;
    },
  },
};
</script>

<template>
  <div class="test-case-sidebar-items">
    <labels-select-widget
      :iid="String(testCaseId)"
      :full-path="projectFullPath"
      :allow-label-remove="canEditTestCase"
      :allow-multiselect="true"
      :issuable-type="$options.TYPE_TEST_CASE"
      :attr-workspace-path="projectFullPath"
      workspace-type="project"
      class="block labels js-labels-block"
      variant="sidebar"
      :label-create-type="$options.WORKSPACE_PROJECT"
      :labels-filter-base-path="testCasesPath"
      @toggleCollapse="handleLabelsCollapsedButtonClick"
    >
      {{ __('None') }}
    </labels-select-widget>
    <sidebar-confidentiality-widget
      :iid="String(testCaseId)"
      :full-path="projectFullPath"
      :issuable-type="$options.TYPE_TEST_CASE"
      @expandSidebar="expandSidebar"
      @closeForm="handleSidebarDropdownClose"
    />
    <project-select
      v-if="canMoveTestCase && !moved"
      :projects-fetch-path="projectsFetchPath"
      :dropdown-button-title="selectProjectDropdownButtonTitle"
      :dropdown-header-title="__('Move test case')"
      :move-in-progress="testCaseMoveInProgress"
      class="block"
      @dropdown-close="handleSidebarDropdownClose"
      @toggle-collapse="handleProjectsCollapsedButtonClick"
      @move-issuable="moveTestCase"
    />
  </div>
</template>
