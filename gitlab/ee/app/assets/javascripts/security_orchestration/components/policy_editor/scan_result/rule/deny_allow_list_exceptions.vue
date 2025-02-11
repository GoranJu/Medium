<script>
import { debounce } from 'lodash';
import { GlCollapsibleListbox, GlFormTextarea, GlSprintf } from '@gitlab/ui';
import { s__, sprintf } from '~/locale';
import {
  EXCEPTION_KEY,
  EXCEPTION_TYPE_ITEMS,
  NO_EXCEPTION_KEY,
} from 'ee/security_orchestration/components/policy_editor/constants';
import {
  splitItemsByCommaOrSpace,
  parseExceptionsStringToItems,
  mapObjectsToString,
} from 'ee/security_orchestration/components/policy_editor/utils';
import { DEFAULT_DEBOUNCE_AND_THROTTLE_MS } from '~/lib/utils/constants';

export default {
  i18n: {
    exceptionMessage: s__(
      'ScanResultPolicy|Use purl format for package paths: %{schemaStart}scheme:type/namespace/name@version?qualifiers#subpath%{schemaEnd}. For multiple packages, separate paths with comma ",".',
    ),
    errorMessage: s__(
      'SecurityOrchestration|Add project full path after @ to following exceptions: %{exceptions}',
    ),
    duplicatesError: s__('ScanResultPolicy|Duplicates will be removed'),
  },
  EXCEPTION_TYPE_ITEMS: [
    {
      value: EXCEPTION_KEY,
      text: s__('SecurityOrchestration|Except'),
    },
    {
      value: NO_EXCEPTION_KEY,
      text: s__('SecurityOrchestration|No exceptions'),
    },
  ],
  name: 'DenyAllowListExceptions',
  components: {
    GlCollapsibleListbox,
    GlFormTextarea,
    GlSprintf,
  },
  props: {
    disabled: {
      type: Boolean,
      required: false,
      default: false,
    },
    exceptionType: {
      type: String,
      required: false,
      default: NO_EXCEPTION_KEY,
    },
    exceptions: {
      type: Array,
      required: false,
      default: () => [],
    },
  },
  data() {
    const { parsedExceptions = [], parsedWithErrorsExceptions = [] } = parseExceptionsStringToItems(
      this.exceptions,
    );

    return {
      parsedExceptions,
      parsedWithErrorsExceptions,
    };
  },
  computed: {
    withExceptions() {
      return this.exceptionType === EXCEPTION_KEY;
    },
    toggleText() {
      return EXCEPTION_TYPE_ITEMS.find(({ value }) => value === this.exceptionType).text;
    },
    convertedToStringPackages() {
      return mapObjectsToString(this.parsedExceptions, 'file');
    },
    hasDuplicates() {
      const items = new Set(splitItemsByCommaOrSpace(this.convertedToStringPackages));

      return items.size < this.parsedExceptions.length;
    },
    hasValidationError() {
      return this.parsedWithErrorsExceptions.length > 0;
    },
    errorMessage() {
      return sprintf(this.$options.i18n.errorMessage, {
        exceptions: this.parsedWithErrorsExceptions.join(' '),
      });
    },
  },
  created() {
    this.debouncedSetExceptions = debounce(this.setExceptions, DEFAULT_DEBOUNCE_AND_THROTTLE_MS);
  },
  destroyed() {
    this.debouncedSetExceptions.cancel();
  },
  methods: {
    parsePackages(packages) {
      const { parsedExceptions = [], parsedWithErrorsExceptions = [] } =
        parseExceptionsStringToItems(packages);

      this.parsedExceptions = parsedExceptions;
      this.parsedWithErrorsExceptions = parsedWithErrorsExceptions;
    },
    setExceptions(packages) {
      const split = splitItemsByCommaOrSpace(packages);
      this.parsePackages(split);

      this.$emit('input', split);
    },
    selectExceptionType(type) {
      this.$emit('select-exception-type', type);
    },
  },
};
</script>

<template>
  <div>
    <gl-collapsible-listbox
      :disabled="disabled"
      size="small"
      :items="$options.EXCEPTION_TYPE_ITEMS"
      :toggle-text="toggleText"
      :selected="exceptionType"
      @select="selectExceptionType"
    />

    <div v-if="withExceptions" class="gl-mt-4">
      <gl-form-textarea
        no-resize
        :value="convertedToStringPackages"
        @input="debouncedSetExceptions"
      />

      <p
        v-if="hasDuplicates && !hasValidationError"
        data-testid="error-duplicates-message"
        class="gl-my-2 gl-text-red-500"
      >
        {{ $options.i18n.duplicatesError }}
      </p>

      <p
        v-if="hasValidationError"
        data-testid="error-validation-message"
        class="gl-my-2 gl-text-red-500"
      >
        {{ errorMessage }}
      </p>

      <p data-testid="format-description" class="gl-mt-3">
        <gl-sprintf :message="$options.i18n.exceptionMessage">
          <template #schema="{ content }">
            <code>{{ content }}</code>
          </template>
        </gl-sprintf>
      </p>
    </div>
  </div>
</template>
