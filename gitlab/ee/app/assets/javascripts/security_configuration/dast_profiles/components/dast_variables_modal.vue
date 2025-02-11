<script>
import {
  GlModal,
  GlCollapsibleListbox,
  GlFormGroup,
  GlFormInput,
  GlFormTextarea,
  GlFormRadio,
  GlFormRadioGroup,
  GlSprintf,
  GlLink,
  GlButton,
} from '@gitlab/ui';
import { s__ } from '~/locale';
import DAST_VARIABLES from '../dast_variables';
import { booleanOptions, getEmptyVariable } from '../constants';

export default {
  name: 'DastVariablesModal',
  components: {
    GlModal,
    GlCollapsibleListbox,
    GlFormGroup,
    GlFormInput,
    GlFormRadio,
    GlFormTextarea,
    GlFormRadioGroup,
    GlSprintf,
    GlLink,
    GlButton,
  },
  props: {
    preSelectedVariables: {
      type: Array,
      required: false,
      default: () => [],
    },
    variable: {
      type: Object,
      required: false,
      default: () => getEmptyVariable(),
    },
  },
  data() {
    return {
      selectedVariable: {
        ...this.variable,
      },
      searchTerm: '',
      selectedValueValid: true,
      selectedVariableValid: true,
      isEdit: false,
    };
  },
  computed: {
    dropdownText() {
      if (this.selectedVariable.id) {
        return this.selectedVariable.id;
      }
      return this.i18n.dropdownPlaceholder;
    },
    items() {
      let filteredVariables = {};
      if (this.isEdit) {
        filteredVariables = Object.entries(DAST_VARIABLES);
      } else {
        const preSelectedVariablesNames = this.preSelectedVariables
          .map((existVariable) => existVariable.variable)
          .filter(Boolean);

        const searchTermLower = this.searchTerm?.toLowerCase() || '';

        filteredVariables = Object.entries(DAST_VARIABLES).filter(
          ([id]) =>
            (!searchTermLower || id.toLowerCase().includes(searchTermLower)) &&
            !preSelectedVariablesNames.includes(id),
        );
      }
      return filteredVariables.map(([id, { description }]) => ({
        value: id,
        text: id,
        secondaryText: description.message || '',
      }));
    },
    componentByType() {
      if (this.selectedVariable.type) {
        if (this.checkSelectorType('selector')) {
          return GlFormTextarea;
        }

        return GlFormInput;
      }
      return null;
    },
    i18n() {
      return {
        title: this.isEdit
          ? s__('DastProfiles|Edit DAST variable')
          : s__('DastProfiles|Add DAST variable'),
        dropdownPlaceholder: s__('DastProfiles|Select a variable'),
        searchPlaceholder: s__('DastProfiles|Search...'),
        emptySearchResult: s__('DastProfiles|No variables found'),
        variableLabel: s__('DastProfiles|Variable'),
        valueLabel: s__('DastProfiles|Value'),
        delete: s__('DastProfiles|Delete'),
        submit: this.isEdit
          ? s__('DastProfiles|Update variable')
          : s__('DastProfiles|Add variable'),
        requiredFieldFeedback: s__('DastProfiles|Field must not be blank'),
      };
    },
  },
  methods: {
    extendSelectedVariable() {
      const { type, description, example } = DAST_VARIABLES[this.selectedVariable.id] || {};
      this.selectedVariable.type = type || null;
      this.selectedVariable.description = description || '';
      this.selectedVariable.example = example || '';
    },
    show() {
      this.$refs.modal.show();
    },
    close() {
      this.$refs.modal.hide();
    },
    onDelete() {
      const { id, value } = this.selectedVariable;
      this.$emit('deleteVariable', {
        variable: id,
        value,
      });
      this.close();
    },
    editVariable() {
      this.isEdit = true;
      this.selectedVariableValid = true;
      this.selectedValueValid = true;
      this.selectedVariable = { ...this.variable };
      this.extendSelectedVariable();
      this.show();
    },
    createVariable() {
      this.isEdit = false;
      this.selectedVariableValid = true;
      this.selectedValueValid = true;
      this.extendSelectedVariable();
      this.show();
    },
    addOrUpdateVariable(modalEvent) {
      if (!this.selectedVariable.type) {
        this.selectedVariableValid = false;
        modalEvent.preventDefault();
        return;
      }
      if (!this.selectedVariable.id || this.selectedVariable.value === '') {
        this.selectedValueValid = false;
        modalEvent.preventDefault();
        return;
      }
      const { id, value } = this.selectedVariable;
      this.$emit(this.isEdit ? 'updateVariable' : 'addVariable', {
        variable: id,
        value: value.toString(),
      });
      this.close();
    },
    onSearch(searchTerm) {
      this.searchTerm = searchTerm.trim().toLowerCase();
    },
    resetModal() {
      this.selectedVariable = getEmptyVariable();
      this.searchTerm = '';
    },
    onSelect(id) {
      this.selectedVariable.id = id;
      this.selectedVariable.value = '';
      this.selectedValueValid = true;
      this.selectedVariableValid = true;
      this.extendSelectedVariable();
    },
    checkSelectorType(type) {
      return this.selectedVariable.type === type;
    },
  },
  booleanOptions,
};
</script>

<template>
  <gl-modal
    ref="modal"
    size="sm"
    modal-id="dast-variable-modal"
    :title="i18n.title"
    @primary="addOrUpdateVariable"
    @hidden="resetModal"
  >
    <gl-form-group
      :label="i18n.variableLabel"
      label-for="dast_variable_selector"
      :invalid-feedback="i18n.requiredFieldFeedback"
      :state="selectedVariableValid"
    >
      <gl-collapsible-listbox
        id="dast_variable_selector"
        block
        searchable
        is-check-centered
        :items="items"
        :toggle-text="dropdownText"
        :search-placeholder="i18n.searchPlaceholder"
        :no-results-text="i18n.emptySearchResult"
        :disabled="isEdit"
        fluid-width
        @search="onSearch"
        @select="onSelect($event)"
      >
        <template #list-item="{ item: { text, secondaryText } }">
          <strong>{{ text }}</strong>
          <div class="gl-text-sm gl-text-subtle">
            <gl-sprintf :message="secondaryText">
              <template #link="{ content }">
                {{ content }}
              </template>
            </gl-sprintf>
          </div>
        </template>
      </gl-collapsible-listbox>
    </gl-form-group>
    <gl-form-group
      v-if="selectedVariable.type"
      :label="i18n.valueLabel"
      :label-description="selectedVariable.description.message"
      label-for="dast_value_input"
      :invalid-feedback="i18n.requiredFieldFeedback"
      :state="selectedValueValid"
    >
      <template v-if="selectedVariable.description" #label-description>
        <gl-sprintf :message="selectedVariable.description.message">
          <template #link="{ content }">
            <gl-link
              v-if="selectedVariable.description.path"
              :href="selectedVariable.description.path"
              target="_blank"
              >{{ content }}</gl-link
            >
            <span v-else>{{ content }}</span>
          </template>
        </gl-sprintf>
      </template>

      <gl-form-radio-group
        v-if="checkSelectorType('boolean')"
        id="dast_value_input"
        v-model="selectedVariable.value"
      >
        <gl-form-radio
          v-for="option in $options.booleanOptions"
          :key="option.value"
          :value="option.value"
        >
          {{ option.text }}
        </gl-form-radio>
      </gl-form-radio-group>

      <component
        :is="componentByType"
        v-else
        id="dast_value_input"
        v-model="selectedVariable.value"
        :placeholder="`Ex: ${selectedVariable.example}`"
        no-resize
      />
    </gl-form-group>

    <template #modal-footer>
      <div :class="{ 'flex-fill gl-flex gl-justify-between': isEdit }">
        <gl-button
          v-if="isEdit"
          category="secondary"
          variant="danger"
          data-testid="delete-btn"
          @click="onDelete"
        >
          {{ i18n.delete }}
        </gl-button>
        <div>
          <gl-button data-testid="cancel-btn" @click="close">{{ __('Cancel') }}</gl-button>
          <gl-button
            category="primary"
            variant="confirm"
            data-testid="submit-btn"
            @click="addOrUpdateVariable"
            >{{ i18n.submit }}</gl-button
          >
        </div>
      </div>
    </template>
  </gl-modal>
</template>
