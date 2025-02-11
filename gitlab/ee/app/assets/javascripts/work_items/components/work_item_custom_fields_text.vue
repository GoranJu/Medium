<script>
import {
  GlButton,
  GlForm,
  GlFormInput,
  GlLoadingIcon,
  GlLink,
  GlTooltipDirective,
  GlTruncate,
} from '@gitlab/ui';
import { CUSTOM_FIELDS_TYPE_TEXT } from '~/work_items/constants';
import { isValidURL } from '~/lib/utils/url_utility';

export const CHARACTER_LIMIT = 540;

export default {
  CHARACTER_LIMIT,
  inputId: 'custom-field-text-input',
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlButton,
    GlForm,
    GlFormInput,
    GlLoadingIcon,
    GlLink,
    GlTruncate,
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
          customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_TEXT &&
          (customField.value == null || typeof customField.value === 'string')
        );
      },
    },
  },
  data() {
    return {
      isEditing: false,
      isUpdating: false,
      clickingClearButton: false,
      workItem: {},
      value: this.customField.value,
      charsLeft: null,
      displayCharsLeft: false,
    };
  },
  computed: {
    id() {
      return this.customField.customField?.id;
    },
    label() {
      return this.customField.customField?.name;
    },
    hasValue() {
      if (this.isValueValid) {
        return !this.isValueEmpty;
      }
      return false;
    },
    isValueValid() {
      return this.value !== null && typeof this.value === 'string';
    },
    isValueEmpty() {
      return !this.value.trim();
    },
    showRemoveValue() {
      return this.hasValue && !this.isUpdating;
    },
    displayWidget() {
      return this.customField.customField?.fieldType === CUSTOM_FIELDS_TYPE_TEXT;
    },
  },
  watch: {
    value(newValue) {
      this.checkDisplayCharsLeft(newValue);
    },
  },
  mounted() {
    if (this.isValueValid) {
      this.checkDisplayCharsLeft();
    }
  },
  methods: {
    blurInput() {
      this.$refs.input.$el.blur();
    },
    handleFocus() {
      this.isEditing = true;
    },
    isLink(value) {
      return isValidURL(value);
    },
    getCharsLeft() {
      if (this.value == null || this.isValueEmpty) {
        return CHARACTER_LIMIT;
      }
      return CHARACTER_LIMIT - this.value.length;
    },
    checkDisplayCharsLeft() {
      this.charsLeft = this.getCharsLeft();

      // only display warning if we're over 90% the characters limit
      this.displayCharsLeft = this.charsLeft <= CHARACTER_LIMIT * 0.1;
    },
    updateTextFromInput(event) {
      if (event.target.value === '') {
        this.updateText(null);
        return;
      }

      const value = String(event.target.value);
      this.updateText(value);
    },
    updateText(text) {
      // @todo add mutation logic
      this.value = text;
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
        data-testid="edit-text"
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
          data-testid="apply-text"
          category="tertiary"
          size="small"
          class="gl-ml-auto"
          :disabled="isUpdating"
          @click="isEditing = false"
          >{{ __('Apply') }}</gl-button
        >
      </div>
      <!-- wrapper for the form input so the borders fit inside the sidebar -->
      <div class="gl-flex gl-items-center gl-gap-2 gl-px-2">
        <gl-form-input
          :id="$options.inputId"
          ref="input"
          v-model="value"
          :maxlength="$options.CHARACTER_LIMIT"
          class="hide-unfocused-input-decoration gl-block"
          :disabled="isUpdating"
          :placeholder="__('Enter text')"
          autofocus
          @blur="updateTextFromInput"
          @focus="handleFocus"
          @keydown.exact.esc.stop="blurInput"
        />
        <gl-button
          v-if="showRemoveValue"
          v-gl-tooltip
          variant="default"
          category="tertiary"
          size="small"
          name="clear"
          icon="clear"
          class="gl-clear-icon-button"
          :title="__('Remove value')"
          :aria-label="__('Remove value')"
          @mousedown="clickingClearButton = true"
          @mouseup="clickingClearButton = false"
          @click="updateText(null)"
        />
      </div>
      <span v-if="displayCharsLeft" class="gl-text-subtle">{{
        n__('%d character remaining.', '%d characters remaining.', charsLeft)
      }}</span>
    </gl-form>
    <template v-else-if="hasValue">
      <div v-if="isLink(value)" class="gl-flex">
        <gl-link
          v-gl-tooltip
          is-unsafe-link
          target="_blank"
          class="gl-truncate"
          :href="value"
          :title="value"
          data-testid="custom-field-value"
        >
          {{ value }}
        </gl-link>
      </div>
      <template v-else>
        <span v-gl-tooltip :title="value">
          <gl-truncate :text="value" data-testid="custom-field-value" />
        </span>
      </template>
    </template>
    <template v-else>
      <div class="gl-text-subtle" data-testid="custom-field-value">{{ __('None') }}</div>
    </template>
  </div>
</template>
