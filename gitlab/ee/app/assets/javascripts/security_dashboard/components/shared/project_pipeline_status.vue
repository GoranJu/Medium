<script>
import { GlLink, GlIcon } from '@gitlab/ui';
import { __, s__ } from '~/locale';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import PipelineStatusBadge from './pipeline_status_badge.vue';

export default {
  components: {
    GlLink,
    GlIcon,
    TimeAgoTooltip,
    PipelineStatusBadge,
  },
  props: {
    pipeline: { type: Object, required: true },
    sbomPipeline: { type: Object, required: false, default: null },
  },
  computed: {
    parsingStatusMessage() {
      return this.parseStatusMessage(this.pipeline);
    },
    sbomParsingStatusMessage() {
      return this.parseStatusMessage(this.sbomPipeline);
    },
    showSbomPipelineStatus() {
      return Boolean(this.sbomPipeline?.id);
    },
  },
  methods: {
    parseStatusMessage(pipeline) {
      const { hasParsingErrors, hasParsingWarnings } = pipeline;

      if (hasParsingErrors && hasParsingWarnings) {
        return this.$options.i18n.hasParsingErrorsAndWarnings;
      }
      if (hasParsingErrors) {
        return this.$options.i18n.hasParsingErrors;
      }
      if (hasParsingWarnings) {
        return this.$options.i18n.hasParsingWarnings;
      }

      return '';
    },
  },
  i18n: {
    lastUpdated: __('Security reports last updated'),
    hasParsingErrorsAndWarnings: s__('SecurityReports|Parsing errors and warnings in pipeline'),
    hasParsingErrors: s__('SecurityReports|Parsing errors in pipeline'),
    hasParsingWarnings: s__('SecurityReports|Parsing warnings in pipeline'),
    sbomLastUpdated: __('SBOMs last updated'),
  },
};
</script>

<template>
  <div class="gl-items-center gl-border-1 gl-border-solid gl-border-default gl-p-6 lg:gl-flex">
    <div class="gl-flex gl-items-center" data-testid="pipeline">
      <div class="gl-mr-3">
        <span class="gl-mr-3 gl-font-bold">{{ $options.i18n.lastUpdated }}</span
        ><span class="gl-whitespace-nowrap">
          <time-ago-tooltip class="gl-pr-3" :time="pipeline.createdAt" /><gl-link
            :href="pipeline.path"
            >#{{ pipeline.id }}</gl-link
          >
          <pipeline-status-badge :pipeline="pipeline" class="gl-ml-3" />
        </span>
      </div>
      <div
        v-if="parsingStatusMessage"
        class="gl-ml-2 gl-font-bold gl-text-orange-400"
        data-testid="parsing-status-notice"
      >
        <gl-icon name="warning" class="gl-mr-3" />{{ parsingStatusMessage }}
      </div>
    </div>

    <template v-if="showSbomPipelineStatus">
      <div class="gl-mx-3 gl-hidden lg:gl-block" data-testid="pipeline-divider">•</div>

      <div class="gl-mt-5 gl-items-center md:gl-flex lg:gl-mt-0" data-testid="sbom-pipeline">
        <div>
          <span class="gl-mr-3 gl-font-bold">{{ $options.i18n.sbomLastUpdated }}</span
          ><span class="gl-whitespace-nowrap">
            <time-ago-tooltip class="gl-pr-3" :time="sbomPipeline.createdAt" /><gl-link
              :href="sbomPipeline.path"
              >#{{ sbomPipeline.id }}</gl-link
            >
            <pipeline-status-badge :pipeline="sbomPipeline" class="gl-ml-3" />
          </span>
        </div>
        <div
          v-if="sbomParsingStatusMessage"
          class="gl-ml-2 gl-mr-3 gl-mt-5 gl-font-bold gl-text-orange-400 md:gl-mt-0"
          data-testid="parsing-status-notice"
        >
          <gl-icon name="warning" class="gl-mr-3" />{{ sbomParsingStatusMessage }}
        </div>
      </div>
    </template>
  </div>
</template>
