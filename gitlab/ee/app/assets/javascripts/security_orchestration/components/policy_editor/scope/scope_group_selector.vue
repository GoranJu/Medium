<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_GROUP, TYPENAME_PROJECT } from '~/graphql_shared/constants';
import {
  EXCEPT_PROJECTS,
  WITHOUT_EXCEPTIONS,
  GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS,
  GROUP_EXCEPTION_TYPE_TEXTS,
  EXCEPTION_TYPE_LISTBOX_ITEMS,
} from 'ee/security_orchestration/components/policy_editor/scope/constants';
import PolicyPopover from 'ee/security_orchestration/components/policy_popover.vue';
import GroupProjectsDropdown from '../../shared/group_projects_dropdown.vue';
import LinkedItemsDropdown from '../../shared/linked_items_dropdown.vue';

export default {
  EXCEPTION_TYPE_LISTBOX_ITEMS,
  GROUP_EXCEPTION_TYPE_LISTBOX_ITEMS,
  LINKED_GROUP_PATH: helpPagePath('user/application_security/policies/_index.md'),
  i18n: {
    groupErrorDescription: s__('SecurityOrchestration|Failed to load groups'),
    projectErrorDescription: s__('SecurityOrchestration|Failed to load projects'),
    popoverTitle: s__('SecurityOrchestration|What is linked group?'),
    popoverDescription: s__(
      "SecurityDescription|The linked group refers to the groups that are linked to security policy projects. Security policy projects store your organization's security policies. They are identified when policies are created, or when a project is linked as a security policy project. %{linkStart}Learn more%{linkEnd}.",
    ),
  },
  name: 'ScopeGroupSelector',
  components: {
    GlCollapsibleListbox,
    GroupProjectsDropdown,
    LinkedItemsDropdown,
    PolicyPopover,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    groups: {
      type: Object,
      required: true,
      default: () => ({}),
    },
    projects: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    isDirty: {
      type: Boolean,
      required: false,
      default: false,
    },
    groupFullPath: {
      type: String,
      required: false,
      default: null,
    },
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    exceptionType: {
      type: String,
      required: false,
      default: WITHOUT_EXCEPTIONS,
    },
  },
  data() {
    return {
      showExceptionListbox: true,
    };
  },
  computed: {
    selectedExceptionTypeText() {
      return GROUP_EXCEPTION_TYPE_TEXTS[this.exceptionType];
    },
    showGroupProjectsDropdown() {
      return this.exceptionType === EXCEPT_PROJECTS && this.groupsIds.length > 0;
    },
    groupsIds() {
      return this.groups?.including?.map(({ id }) => convertToGraphQLId(TYPENAME_GROUP, id)) || [];
    },
    mappedGroupsIds() {
      return this.groupsIds.map(this.mapToRegularId);
    },
    projectIds() {
      return (
        this.projects?.excluding?.map(({ id }) => convertToGraphQLId(TYPENAME_PROJECT, id)) || []
      );
    },
    mappedProjectIds() {
      return this.projectIds.map(this.mapToRegularId);
    },
    isFieldValid() {
      return !this.groupsEmpty || !this.isDirty;
    },
    groupsEmpty() {
      return this.groupsIds.length === 0;
    },
  },
  methods: {
    selectExceptionType(type) {
      if (type === WITHOUT_EXCEPTIONS) {
        this.$emit(
          'changed',
          this.buildPayload({
            groupIds: this.mappedGroupsIds,
            projectIds: [],
          }),
        );
      }

      this.$emit('select-exception-type', type);
    },
    emitError(error) {
      this.$emit('error', error);
    },
    mapToRegularId(id) {
      return { id: getIdFromGraphQLId(id) };
    },
    mapObjectToRegular({ id }) {
      return this.mapToRegularId(id);
    },
    buildPayload({ groupIds, projectIds }) {
      return {
        groups: {
          including: groupIds,
        },
        projects: {
          excluding: projectIds,
        },
      };
    },
    setSelectedGroups(groups) {
      const projectIds = groups?.length > 0 ? this.mappedProjectIds : [];
      this.$emit(
        'changed',
        this.buildPayload({
          groupIds: groups.map(this.mapObjectToRegular),
          projectIds,
        }),
      );
    },
    setSelectedProjects(projects) {
      this.$emit(
        'changed',
        this.buildPayload({
          projectIds: projects.map(this.mapObjectToRegular),
          groupIds: this.mappedGroupsIds,
        }),
      );
    },
    toggleExceptionListbox(items) {
      this.showExceptionListbox = items.length !== 0;
    },
  },
};
</script>

<template>
  <div class="gl-flex gl-items-center gl-gap-3">
    <linked-items-dropdown
      data-testid="groups-dropdown"
      include-descendants
      :full-path="fullPath"
      :disabled="disabled"
      :selected="groupsIds"
      :state="isFieldValid"
      @loaded="toggleExceptionListbox"
      @linked-items-query-error="emitError($options.i18n.groupErrorDescription)"
      @select="setSelectedGroups"
    />

    <gl-collapsible-listbox
      v-if="showExceptionListbox"
      data-testid="exception-type"
      :disabled="disabled"
      :items="$options.EXCEPTION_TYPE_LISTBOX_ITEMS"
      :toggle-text="selectedExceptionTypeText"
      :selected="exceptionType"
      @select="selectExceptionType"
    />

    <group-projects-dropdown
      v-if="showGroupProjectsDropdown"
      data-testid="projects-dropdown"
      load-all-projects
      :disabled="disabled"
      :group-full-path="groupFullPath"
      :selected="projectIds"
      :state="true"
      @projects-query-error="emitError($options.i18n.projectErrorDescription)"
      @select="setSelectedProjects"
    />

    <policy-popover
      :content="$options.i18n.popoverDescription"
      :title="$options.i18n.popoverTitle"
      :href="$options.LINKED_GROUP_PATH"
      target="linked-groups-scope"
    />
  </div>
</template>
