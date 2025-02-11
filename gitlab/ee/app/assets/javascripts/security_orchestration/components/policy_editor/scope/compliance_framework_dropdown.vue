<script>
import { debounce } from 'lodash';
import { GlButton, GlCollapsibleListbox, GlLabel, GlFormGroup, GlPopover } from '@gitlab/ui';
import { n__, s__, __, sprintf } from '~/locale';
import { convertToGraphQLId, getIdFromGraphQLId } from '~/graphql_shared/utils';
import { TYPE_COMPLIANCE_FRAMEWORK } from '~/graphql_shared/constants';
import getComplianceFrameworkQuery from 'ee/graphql_shared/queries/get_compliance_framework.query.graphql';
import { renderMultiSelectText } from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';
import ComplianceFrameworkFormModal from 'ee/groups/settings/compliance_frameworks/components/form_modal.vue';

export default {
  i18n: {
    complianceFrameworkCreateButton: s__('SecurityOrchestration|Create new framework label'),
    complianceFrameworkHeader: s__('SecurityOrchestration|Select frameworks'),
    complianceFrameworkTypeName: s__('SecurityOrchestration|compliance frameworks'),
    complianceFrameworkPopoverPlaceholder: s__(
      'SecurityOrchestration|Compliance framework has no projects',
    ),
    errorMessage: s__('SecurityOrchestration|At least one framework label should be selected'),
    noFrameworksText: s__('SecurityOrchestration|No compliance frameworks'),
    selectAllLabel: __('Select all'),
    clearAllLabel: __('Clear all'),
  },
  name: 'ComplianceFrameworkDropdown',
  components: {
    ComplianceFrameworkFormModal,
    GlButton,
    GlCollapsibleListbox,
    GlFormGroup,
    GlLabel,
    GlPopover,
  },
  apollo: {
    complianceFrameworks: {
      query: getComplianceFrameworkQuery,
      variables() {
        return {
          fullPath: this.fullPath,
        };
      },
      update(data) {
        return data.namespace?.complianceFrameworks?.nodes || [];
      },
      error() {
        this.$emit('framework-query-error');
      },
    },
  },
  provide() {
    return {
      groupPath: this.fullPath,
      pipelineConfigurationFullPathEnabled: true,
      pipelineConfigurationEnabled: true,
    };
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    fullPath: {
      type: String,
      required: true,
    },
    selectedFrameworkIds: {
      type: Array,
      required: false,
      default: () => [],
    },
    showError: {
      type: Boolean,
      required: false,
      default: false,
    },
    /**
     * selected ids passed as short format
     * [21,34,45] as number
     * needs to be converted to full graphql id
     * if false, selectedFrameworkIds needs to be
     * an array of full graphQl ids
     */
    useShortIdFormat: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      complianceFrameworks: [],
      searchTerm: '',
    };
  },
  computed: {
    formattedSelectedFrameworkIds() {
      if (this.useShortIdFormat) {
        return (
          this.selectedFrameworkIds?.map((id) =>
            convertToGraphQLId(TYPE_COMPLIANCE_FRAMEWORK, id),
          ) || []
        );
      }

      return this.selectedFrameworkIds || [];
    },
    existingFormattedSelectedFrameworkIds() {
      return this.formattedSelectedFrameworkIds.filter((id) =>
        this.complianceFrameworkIds.includes(id),
      );
    },
    complianceFrameworkItems() {
      return this.complianceFrameworks?.reduce((acc, { id, name }) => {
        acc[id] = name;
        return acc;
      }, {});
    },
    dropdownPlaceholder() {
      return renderMultiSelectText({
        selected: this.formattedSelectedFrameworkIds,
        items: this.complianceFrameworkItems,
        itemTypeName: this.$options.i18n.complianceFrameworkTypeName,
        useAllSelected: false,
      });
    },
    listBoxItems() {
      return (
        this.complianceFrameworks?.map(({ id, name, ...framework }) => ({
          value: id,
          text: name,
          ...framework,
        })) || []
      );
    },
    filteredListBoxItems() {
      return this.listBoxItems.filter(({ text }) =>
        text.toLowerCase().includes(this.searchTerm.toLowerCase()),
      );
    },
    complianceFrameworkIds() {
      return this.complianceFrameworks?.map(({ id }) => id);
    },
    loading() {
      return this.$apollo.queries.complianceFrameworks?.loading;
    },
    listBoxCategory() {
      return this.showError ? 'secondary' : 'primary';
    },
    listBoxVariant() {
      return this.showError ? 'danger' : 'default';
    },
  },
  created() {
    this.debouncedSearch = debounce(this.setSearchTerm, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSearch.cancel();
  },
  methods: {
    showCreateFrameworkForm() {
      this.$refs.formModal.show();
    },
    setSearchTerm(searchTerm = '') {
      this.searchTerm = searchTerm.trim();
    },
    /**
     * Only works with ListBox multiple mode
     * Without multiple prop select method emits single id
     * and includes method won't work
     * @param ids selected ids in full graphql format
     */
    selectFrameworks(ids) {
      const payload = this.useShortIdFormat ? ids.map((id) => getIdFromGraphQLId(id)) : ids;
      this.$emit('select', payload);
    },
    onComplianceFrameworkCreated() {
      this.$refs.formModal.hide();
      this.$refs.listbox.open();
    },
    extractProjects(framework) {
      return framework?.projects?.nodes || [];
    },
    renderPopoverContent(framework) {
      return (
        this.extractProjects(framework)
          .map(({ name }) => name)
          .join(', ') || this.$options.i18n.complianceFrameworkPopoverPlaceholder
      );
    },
    renderPopoverTitle(frameworkName, projectLength) {
      const projects = n__('project', 'projects', projectLength);
      return sprintf(
        s__('SecurityOrchestration|%{frameworkName} has %{projectLength} %{projects}'),
        {
          frameworkName,
          projectLength,
          projects,
        },
      );
    },
  },
};
</script>

<template>
  <div>
    <gl-form-group
      class="gl-mb-0"
      label-sr-only
      :label="$options.i18n.errorMessage"
      :state="!showError"
      :optional="false"
      :invalid-feedback="$options.i18n.errorMessage"
    >
      <gl-collapsible-listbox
        ref="listbox"
        block
        multiple
        searchable
        :category="listBoxCategory"
        :variant="listBoxVariant"
        :disabled="disabled"
        :header-text="$options.i18n.complianceFrameworkHeader"
        :loading="loading"
        :no-results-text="$options.i18n.noFrameworksText"
        :items="filteredListBoxItems"
        :reset-button-label="$options.i18n.clearAllLabel"
        :show-select-all-button-label="$options.i18n.selectAllLabel"
        :toggle-text="dropdownPlaceholder"
        :title="dropdownPlaceholder"
        :selected="existingFormattedSelectedFrameworkIds"
        @reset="selectFrameworks([])"
        @search="debouncedSearch"
        @select="selectFrameworks"
        @select-all="selectFrameworks(complianceFrameworkIds)"
      >
        <template #list-item="{ item }">
          <div :id="item.value">
            <gl-label
              :background-color="item.color"
              :description="$options.i18n.editFramework"
              :title="item.text"
              :target="item.editPath"
            />
            <gl-popover
              boundary="viewport"
              placement="right"
              triggers="hover"
              :content="renderPopoverContent(item)"
              :target="item.value"
              :title="renderPopoverTitle(item.text, extractProjects(item).length)"
            />
          </div>
        </template>
        <template #footer>
          <div class="gl-border-t">
            <gl-button
              category="tertiary"
              class="gl-w-full !gl-justify-start"
              target="_blank"
              @click="showCreateFrameworkForm"
            >
              {{ $options.i18n.complianceFrameworkCreateButton }}
            </gl-button>
          </div>
        </template>
      </gl-collapsible-listbox>
    </gl-form-group>

    <compliance-framework-form-modal ref="formModal" @change="onComplianceFrameworkCreated" />
  </div>
</template>
