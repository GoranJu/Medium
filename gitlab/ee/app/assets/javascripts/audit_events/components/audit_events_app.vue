<script>
import { GlTabs, GlTab } from '@gitlab/ui';
import Tracking from '~/tracking';
import { AUDIT_EVENTS_TAB_TITLES } from '../constants';
import AuditEventsLog from './audit_events_log.vue';
import AuditEventsStream from './audit_events_stream.vue';

export default {
  components: {
    GlTabs,
    GlTab,
    AuditEventsLog,
    AuditEventsStream,
  },
  mixins: [Tracking.mixin()],
  inject: {
    isProject: {
      default: false,
    },
    showStreams: {
      default: false,
    },
  },
  computed: {
    showTabs() {
      return !this.isProject && this.showStreams;
    },
  },
  methods: {
    onTabClick() {
      this.track('click_tab', { label: 'audit_events_streams_tab' });
    },
  },
  i18n: AUDIT_EVENTS_TAB_TITLES,
};
</script>

<template>
  <gl-tabs
    v-if="showTabs"
    content-class="gl-pt-0"
    :sync-active-tab-with-query-params="true"
    data-testid="audit-events-tabs"
  >
    <gl-tab :title="$options.i18n.LOG" query-param-value="log">
      <audit-events-log />
    </gl-tab>
    <gl-tab
      :title="$options.i18n.STREAM"
      query-param-value="streams"
      lazy
      data-testid="streams-tab"
      :title-link-attributes="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        'data-testid': 'streams-tab-button',
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      @click="onTabClick"
    >
      <audit-events-stream />
    </gl-tab>
  </gl-tabs>
  <audit-events-log v-else />
</template>
