<script>
import jiraLogo from '@gitlab/svgs/dist/illustrations/logos/jira.svg?raw';
import { GlIcon, GlLink, GlTooltipDirective, GlSprintf } from '@gitlab/ui';
import { STATUS_CLOSED } from '~/issues/constants';
import SafeHtml from '~/vue_shared/directives/safe_html';

export default {
  components: {
    GlIcon,
    GlLink,
    GlSprintf,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
    SafeHtml,
  },
  props: {
    issue: {
      type: Object,
      required: true,
    },
    isJira: {
      type: Boolean,
      required: false,
    },
  },
  computed: {
    iconName() {
      return this.issueIsClosed ? 'issue-closed' : 'issues';
    },
    iconVariant() {
      return this.issueIsClosed ? 'current' : 'success';
    },
    issueIsClosed() {
      return this.issue.state === STATUS_CLOSED;
    },
  },
  jiraLogo,
};
</script>
<template>
  <gl-link
    v-gl-tooltip="issue.title"
    :href="issue.webUrl"
    target="__blank"
    class="gl-inline-flex gl-shrink-0 gl-items-center"
  >
    <span
      v-if="isJira"
      v-safe-html="$options.jiraLogo"
      class="gl-mr-3 gl-inline-flex gl-min-h-6 gl-items-center"
      data-testid="jira-logo"
    ></span>
    <gl-icon v-else class="gl-mr-2" :name="iconName" :variant="iconVariant" />
    <gl-sprintf v-if="issueIsClosed" :message="__('#%{issueIid} (closed)')">
      <template #issueIid>{{ issue.iid }}</template>
    </gl-sprintf>
    <span v-else>#{{ issue.iid }}</span>
    <gl-icon v-if="isJira" :size="12" name="external-link" class="gl-ml-1" />
  </gl-link>
</template>
