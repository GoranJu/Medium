<script>
import { GlButton } from '@gitlab/ui';
import { sendDuoChatCommand } from 'ee/ai/utils';
import { InternalEvents } from '~/tracking';
import { TYPENAME_CI_BUILD } from '~/graphql_shared/constants';
import { convertToGraphQLId } from '~/graphql_shared/utils';

export default {
  components: {
    GlButton,
  },
  mixins: [InternalEvents.mixin()],
  props: {
    canTroubleshootJob: {
      type: Boolean,
      required: true,
    },
    jobStatusGroup: {
      type: String,
      required: true,
    },
    jobId: {
      type: Number,
      required: false,
      default: null,
    },
    jobGid: {
      type: String,
      required: false,
      default: '',
    },
    isBuild: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  computed: {
    resourceId() {
      return this.jobGid || convertToGraphQLId(TYPENAME_CI_BUILD, this.jobId);
    },
    jobFailed() {
      const failedGroups = ['failed', 'failed-with-warnings'];

      return failedGroups.includes(this.jobStatusGroup);
    },
    shouldDisplayButton() {
      return this.jobFailed && this.canTroubleshootJob && this.isBuild;
    },
  },
  mounted() {
    this.trackEvent('render_root_cause_analysis');
  },
  methods: {
    callDuo() {
      this.trackEvent('click_root_cause_analysis');

      sendDuoChatCommand({
        question: '/troubleshoot',
        resourceId: this.resourceId,
      });
    },
  },
};
</script>
<template>
  <div>
    <nav
      v-if="shouldDisplayButton"
      class="rca-bar-component gl-fixed gl-left-0 gl-flex gl-w-full gl-items-center"
      data-testid="rca-bar-component"
    >
      <div class="rca-bar-content gl-flex gl-w-full gl-justify-end" data-testid="rca-bar-content">
        <gl-button icon="duo-chat" variant="confirm" data-testid="rca-duo-button" @click="callDuo">
          {{ s__('Jobs|Troubleshoot') }}
        </gl-button>
      </div>
    </nav>
  </div>
</template>
