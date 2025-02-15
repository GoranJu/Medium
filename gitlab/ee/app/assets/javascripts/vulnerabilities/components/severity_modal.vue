<script>
import {
  GlModal,
  GlForm,
  GlFormGroup,
  GlButton,
  GlCollapsibleListbox,
  GlIcon,
  GlFormTextarea,
} from '@gitlab/ui';
import { __ } from '~/locale';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import { SEVERITY_LEVELS } from 'ee/security_dashboard/constants';

export default {
  components: {
    GlModal,
    GlForm,
    GlFormGroup,
    GlFormTextarea,
    GlButton,
    GlCollapsibleListbox,
    GlIcon,
    SeverityBadge,
  },
  props: {
    modalId: { type: String, required: true },
  },
  data() {
    return {
      severity: null,
      severityValid: true,
      comment: '',
      commentValid: true,
    };
  },
  computed: {
    severityOptions() {
      return Object.keys(SEVERITY_LEVELS).map((key) => ({
        value: key,
        text: SEVERITY_LEVELS[key],
      }));
    },
  },
  methods: {
    selectSeverity(value) {
      this.severity = value;
      this.severityValid = true;
    },
    validate() {
      this.severityValid = Boolean(this.severity);
      this.commentValid = Boolean(this.comment);
    },
    saveChange(event) {
      this.validate();

      if (!this.severityValid || !this.commentValid) {
        event.preventDefault();
        return;
      }

      this.$emit('severityChange', {
        severity: this.severity,
        comment: this.comment,
      });
      this.resetForm();
    },
    resetForm() {
      this.severity = null;
      this.severityValid = true;
      this.comment = '';
      this.commentValid = true;
    },
  },
  actions: {
    primary: { text: __('Save change') },
    cancel: { text: __('Cancel') },
  },
};
</script>
<template>
  <gl-modal
    size="sm"
    :modal-id="modalId"
    :title="s__('VulnerabilityManagement|Change severity')"
    :action-primary="$options.actions.primary"
    :action-cancel="$options.actions.cancel"
    @primary="saveChange"
    @cancel="resetForm"
  >
    <p>
      {{
        s__(
          'VulnerabilityManagement|Change the severity of this vulnerability. Only this vulnerability will be affected.',
        )
      }}
    </p>
    <gl-form>
      <gl-form-group
        label-for="severity"
        :label="s__('VulnerabilityManagement|Severity')"
        :state="severityValid"
        :invalid-feedback="s__('VulnerabilityManagement|Severity is required.')"
        class="gl-mb-2"
        data-testid="severity-form-group"
      >
        <gl-collapsible-listbox
          :items="severityOptions"
          :selected="severity"
          :icon="`severity-${severity}`"
          data-testid="severity"
          @select="selectSeverity"
        >
          <template #toggle>
            <gl-button :class="{ '!gl-border-red-500': !severityValid }">
              <span class="gl-inline-flex">
                <severity-badge v-if="severity" :severity="severity" />
                <span v-else class="text-muted">
                  {{ s__('VulnerabilityManagement|Select a severity') }}
                </span>
                <gl-icon class="gl-ml-3" name="chevron-down" />
              </span>
            </gl-button>
          </template>
          <template #list-item="{ item }">
            <severity-badge :severity="item.value" />
          </template>
        </gl-collapsible-listbox>
      </gl-form-group>
      <gl-form-group
        :state="commentValid"
        :invalid-feedback="s__('VulnerabilityManagement|Comment is required.')"
        data-testid="comment-form-group"
      >
        <gl-form-textarea
          v-model="comment"
          :class="{ '!gl-border !gl-border-red-500': !commentValid }"
          :placeholder="s__('VulnerabilityManagement|Add reason for severity change (Required)')"
          data-testid="comment"
          @change="commentValid = true"
        />
      </gl-form-group>
    </gl-form>
  </gl-modal>
</template>
