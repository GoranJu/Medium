<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { createAlert } from '~/alert';
import glFeatureFlagsMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  mixins: [glFeatureFlagsMixin()],
  inject: ['summarizeClientSubscriptionId'],
  props: {
    resourceGlobalId: {
      type: String,
      required: true,
    },
    loading: {
      type: Boolean,
      default: false,
      required: false,
    },
  },
  data() {
    return {
      errorAlert: null,
      aiCompletionResponse: {},
    };
  },
  destroyed() {
    if (this.timeout) {
      clearTimeout(this.timeout);
    }
  },
  methods: {
    onClick() {
      this.hideTooltips();

      if (this.loading) {
        return;
      }

      sendDuoChatCommand({
        question: '/summarize_comments',
        resourceId: this.resourceGlobalId,
      });
    },
    hideTooltips() {
      this.$nextTick(() => {
        this.$root.$emit(BV_HIDE_TOOLTIP);
      });
    },
    handleError(error) {
      this.hideTooltips();
      const alertOptions = error ? { captureError: true, error } : {};
      this.errorAlert = createAlert({
        message: error ? error.message : __('Something went wrong'),
        ...alertOptions,
      });
      this.$parent.$emit('set-ai-loading', false);
    },
  },
  i18n: {
    button: s__('AISummary|View summary'),
    tooltip: s__('AISummary|Generates a summary of this issue'),
  },
};
</script>

<template>
  <gl-button
    v-gl-tooltip
    icon="duo-chat"
    :disabled="loading"
    :loading="loading"
    :title="$options.i18n.tooltip"
    :aria-label="$options.i18n.tooltip"
    @click="onClick"
    @mouseout="hideTooltips"
  >
    {{ $options.i18n.button }}
  </gl-button>
</template>
