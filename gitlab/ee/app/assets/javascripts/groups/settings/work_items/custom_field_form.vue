<script>
import {
  GlButton,
  GlFormGroup,
  GlFormInput,
  GlFormSelect,
  GlModal,
  GlAlert,
  GlLoadingIcon,
  GlTooltipDirective,
} from '@gitlab/ui';
import { nextTick } from 'vue';
import { __, s__, sprintf } from '~/locale';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import createCustomFieldMutation from './create_custom_field.mutation.graphql';
import updateCustomFieldMutation from './update_custom_field.mutation.graphql';
import groupCustomFieldQuery from './group_custom_field.query.graphql';

export const FIELD_TYPE_OPTIONS = [
  { value: 'SINGLE_SELECT', text: s__('WorkItem|Single select') },
  { value: 'MULTI_SELECT', text: s__('WorkItem|Multi select') },
  { value: 'NUMBER', text: s__('WorkItem|Number') },
  { value: 'TEXT', text: s__('WorkItem|Text') },
];

export default {
  components: {
    GlButton,
    GlFormGroup,
    GlFormInput,
    GlFormSelect,
    GlModal,
    GlAlert,
    GlLoadingIcon,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  inject: ['fullPath'],
  props: {
    customFieldId: {
      type: String,
      required: false,
      default: null,
    },
    customFieldName: {
      type: String,
      required: false,
      default: '',
    },
  },
  data() {
    return {
      visible: false,
      loading: false,
      fieldTypes: FIELD_TYPE_OPTIONS,
      formData: {
        fieldType: FIELD_TYPE_OPTIONS[0].value,
        fieldName: '',
        selectOptions: [{ value: '' }],
      },
      formState: {
        fieldName: null,
        selectOptions: null,
      },
      mutationError: '',
    };
  },
  computed: {
    isSelect() {
      return ['SINGLE_SELECT', 'MULTI_SELECT'].includes(this.formData.fieldType);
    },
    isEditing() {
      return Boolean(this.customFieldId);
    },
    editButtonText() {
      return sprintf(s__('WorkItem|Edit %{fieldName}'), { fieldName: this.customFieldName });
    },
    modalTitle() {
      return this.isEditing
        ? sprintf(s__('WorkItem|Edit custom field %{fieldName}'), {
            fieldName: this.customFieldName,
          })
        : s__('WorkItem|New custom field');
    },
    saveButtonText() {
      return this.isEditing ? __('Update') : __('Save');
    },
  },
  methods: {
    async addSelectOption() {
      this.formData.selectOptions.push({ value: '' });
      await nextTick();
      this.$refs[`selectOptions${this.formData.selectOptions.length - 1}`][0].$el.focus();
    },
    removeSelectOption(index) {
      this.formData.selectOptions.splice(index, 1);
      this.validateSelectOptions();
    },
    focusNameInput() {
      this.$refs.nameInput.$el.focus();
    },
    validateForm() {
      this.validateFieldName();
      if (this.isSelect) {
        this.validateSelectOptions();
      }
      return Object.values(this.formState).every((state) => state !== false);
    },
    validateFieldName() {
      this.formState.fieldName = this.formData.fieldName.trim() !== '';
    },
    validateSelectOptions() {
      this.formState.selectOptions = this.formData.selectOptions.some(
        (option) => option.value.trim() !== '',
      );
    },
    removeEmptyOptions() {
      this.formData.selectOptions = this.formData.selectOptions.filter((option) =>
        option.value.trim(),
      );
    },
    async saveCustomField() {
      if (!this.validateForm()) {
        return;
      }
      this.removeEmptyOptions();
      this.mutationError = '';
      this.loading = true;
      try {
        const mutation = this.isEditing ? updateCustomFieldMutation : createCustomFieldMutation;
        const variables = this.isEditing
          ? {
              id: this.customFieldId,
              name: this.formData.fieldName,
              selectOptions: this.isSelect
                ? this.formData.selectOptions.map((opt) => ({
                    id: opt.id,
                    value: opt.value,
                  }))
                : undefined,
            }
          : {
              groupPath: this.fullPath,
              name: this.formData.fieldName,
              fieldType: this.formData.fieldType,
              selectOptions: this.isSelect ? this.formData.selectOptions : undefined,
            };

        const { data } = await this.$apollo.mutate({
          mutation,
          variables,
        });

        const resultKey = this.isEditing ? 'customFieldUpdate' : 'customFieldCreate';
        if (data?.[resultKey]?.errors?.length) {
          throw new Error(data[resultKey].errors[0]);
        }

        this.$emit(this.isEditing ? 'updated' : 'created');
        this.visible = false;
      } catch (error) {
        Sentry.captureException(error);
        this.mutationError =
          error.message ||
          s__('WorkItemCustomField|An error occurred while saving the custom field');
      } finally {
        this.loading = false;
      }
    },
    async loadCustomField() {
      if (!this.isEditing) return;

      this.loading = true;
      try {
        const { data } = await this.$apollo.query({
          query: groupCustomFieldQuery,
          variables: {
            fullPath: this.fullPath,
            fieldId: this.customFieldId,
          },
        });

        const customField = data?.group?.customField;
        if (customField) {
          const { name, fieldType, selectOptions } = customField;
          this.formData = {
            fieldName: name,
            fieldType,
            selectOptions:
              selectOptions.length > 0
                ? JSON.parse(JSON.stringify(selectOptions))
                : [{ value: '' }],
          };
        }
      } catch (error) {
        Sentry.captureException(error);
        this.mutationError = s__(
          'WorkItemCustomField|An error occurred while loading the custom field',
        );
      } finally {
        this.loading = false;
      }
    },
    openModal() {
      this.visible = true;
      this.loadCustomField();
    },
  },
};
</script>

<template>
  <div>
    <gl-button
      v-if="isEditing"
      v-gl-tooltip="editButtonText"
      :aria-label="editButtonText"
      icon="pencil"
      category="tertiary"
      data-testid="toggle-edit-modal"
      @click="openModal"
    />
    <gl-button v-else size="small" data-testid="toggle-modal" @click="openModal">{{
      s__('WorkItem|Create field')
    }}</gl-button>
    <gl-modal
      :modal-id="isEditing ? 'edit-work-item-custom-field' : 'new-work-item-custom-field'"
      :visible="visible"
      :title="modalTitle"
      @shown="focusNameInput"
      @hide="visible = false"
    >
      <gl-loading-icon v-if="loading" size="lg" class="gl-my-7" />
      <template v-else>
        <gl-form-group
          v-if="!isEditing"
          :label="s__('WorkItemCustomField|Type')"
          label-for="field-type"
        >
          <gl-form-select
            id="field-type"
            v-model="formData.fieldType"
            :options="fieldTypes"
            width="md"
          />
        </gl-form-group>

        <gl-form-group
          :label="s__('WorkItemCustomField|Name')"
          label-for="field-name"
          data-testid="custom-field-name"
          :invalid-feedback="s__('WorkItemCustomField|Name is required.')"
          :state="formState.fieldName"
        >
          <gl-form-input
            id="field-name"
            ref="nameInput"
            v-model="formData.fieldName"
            width="md"
            :state="formState.fieldName"
            @input="validateFieldName"
          />
        </gl-form-group>

        <gl-form-group
          v-if="isSelect"
          :label="s__('WorkItemCustomField|Options')"
          data-testid="custom-field-options"
          :state="formState.selectOptions"
          :invalid-feedback="s__('WorkItemCustomField|At least one option is required.')"
        >
          <div
            v-for="(selectOption, index) in formData.selectOptions"
            :key="index"
            class="gl-mb-3 gl-flex"
          >
            <gl-form-input
              :ref="`selectOptions${index}`"
              v-model="selectOption.value"
              width="md"
              :data-testid="`select-options-${index}`"
              @input="validateSelectOptions"
            />
            <gl-button
              category="tertiary"
              icon="remove"
              :aria-label="s__('WorkItemCustomField|Remove')"
              :data-testid="`remove-select-option-${index}`"
              @click="removeSelectOption(index)"
            />
          </div>

          <gl-button
            data-testid="add-select-option"
            category="tertiary"
            icon="plus"
            @click="addSelectOption"
            >{{ s__('WorkItemCustomField|Add option') }}</gl-button
          >
        </gl-form-group>

        <gl-alert v-if="mutationError" variant="danger" :dismissible="false" class="gl-mt-5">
          {{ mutationError }}
        </gl-alert>
      </template>

      <template #modal-footer>
        <gl-button @click="visible = false">{{ __('Cancel') }}</gl-button>
        <gl-button
          :data-testid="isEditing ? 'update-custom-field' : 'save-custom-field'"
          variant="confirm"
          @click="saveCustomField"
          >{{ saveButtonText }}</gl-button
        >
      </template>
    </gl-modal>
  </div>
</template>
