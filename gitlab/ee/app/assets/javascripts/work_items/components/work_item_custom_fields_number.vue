<script>
import { GlButton, GlForm, GlFormInput, GlLoadingIcon, GlTooltipDirective } from '@gitlab/ui';
import { CUSTOM_FIELDS_TYPE_NUMBER } from '~/work_items/constants';

export default {
  inputId: 'custom-field-number-input',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlForm,
    GlFormInput,
    GlLoadingIcon,
  },
  props: {
    canUpdate: {
      type: Boolean,
      required: false,
      default: false,
    },
    customField: {
      type: Object,
      required: true,
      validator: (customField) => {
        return (
          customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_NUMBER &&
          (customField.value === null || Number.isFinite(Number(customField.value)))
        );
      },
    },
  },
  data() {
    return {
      value: this.customField.value,
      isEditing: false,
      isUpdating: false,
    };
  },
  computed: {
    label() {
      return this.customField.customField?.name;
    },
    hasValue() {
      return this.value !== null && Number.isFinite(Number(this.value));
    },
    showRemoveValue() {
      return this.hasValue && !this.isUpdating;
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_NUMBER;
    },
  },
  methods: {
    blurInput() {
      this.$refs.input.$el.blur();
    },
    handleFocus() {
      this.isEditing = true;
    },
    updateNumberFromInput(event) {
      if (event.target.value.trim() === '') {
        this.updateNumber(null);
        return;
      }

      const value = Number(event.target.value);
      this.updateNumber(value);
    },
    updateNumber(number) {
      // @todo add mutation logic
      this.value = number;
      this.isEditing = false;
      this.isUpdating = false;
    },
  },
};
</script>

<template>
  <div v-if="displayWidget">
    <div class="gl-flex gl-items-center gl-justify-between">
      <!-- hide header when editing, since we then have a form label. Keep it reachable for screenreader nav  -->
      <h3 :class="{ 'gl-sr-only': isEditing }" class="gl-heading-5 !gl-mb-0">
        {{ label }}
      </h3>
      <gl-button
        v-if="canUpdate && !isEditing"
        data-testid="edit-number"
        class="flex-shrink-0"
        category="tertiary"
        size="small"
        @click="isEditing = true"
        >{{ __('Edit') }}</gl-button
      >
    </div>
    <gl-form v-if="isEditing" @submit.prevent="blurInput">
      <div class="gl-flex gl-items-center">
        <label :for="$options.inputId" class="gl-mb-0">{{ label }}</label>
        <gl-loading-icon v-if="isUpdating" size="sm" inline class="gl-ml-3" />
        <gl-button
          data-testid="apply-number"
          category="tertiary"
          size="small"
          class="gl-ml-auto"
          :disabled="isUpdating"
          @click="isEditing = false"
          >{{ __('Apply') }}</gl-button
        >
      </div>
      <!-- wrapper for the form input so the borders fit inside the sidebar -->
      <div class="gl-relative gl-px-2">
        <gl-form-input
          :id="$options.inputId"
          ref="input"
          min="0"
          class="hide-unfocused-input-decoration gl-block"
          type="number"
          :disabled="isUpdating"
          :placeholder="__('Enter a number')"
          :value="value"
          autofocus
          @blur="updateNumberFromInput"
          @focus="handleFocus"
          @keydown.exact.esc.stop="blurInput"
        />
      </div>
    </gl-form>
    <template v-else-if="hasValue">
      <div data-testid="custom-field-value">{{ value }}</div>
    </template>
    <template v-else>
      <div class="gl-text-subtle" data-testid="custom-field-value">{{ __('None') }}</div>
    </template>
  </div>
</template>
