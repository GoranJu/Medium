<script>
import { GlLoadingIcon } from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapState, mapActions } from 'vuex';
import { generateInitialStageData } from 'ee/analytics/cycle_analytics/components/create_value_stream_form/utils';
import { mergeUrlParams } from '~/lib/utils/url_utility';
import ValueStreamFormContent from './value_stream_form_content.vue';

export default {
  name: 'ValueStreamForm',
  components: {
    ValueStreamFormContent,
    GlLoadingIcon,
  },
  inject: {
    vsaPath: {
      default: null,
    },
  },
  props: {
    isEditing: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  computed: {
    ...mapState({
      selectedValueStream: 'selectedValueStream',
      selectedValueStreamStages: 'stages',
      initialFormErrors: 'createValueStreamErrors',
      defaultStageConfig: 'defaultStageConfig',
      defaultGroupLabels: 'defaultGroupLabels',
      isFetchingGroupStagesAndEvents: 'isFetchingGroupStagesAndEvents',
      isFetchingGroupLabels: 'isFetchingGroupLabels',
      isValueStreamLoading: 'isLoading',
    }),
    isLoading() {
      return (
        this.isValueStreamLoading ||
        this.isFetchingGroupLabels ||
        this.isFetchingGroupStagesAndEvents
      );
    },
    initialData() {
      return this.isEditing
        ? {
            ...this.selectedValueStream,
            stages: generateInitialStageData(
              this.defaultStageConfig,
              this.selectedValueStreamStages,
            ),
          }
        : {
            name: '',
            stages: [],
          };
    },
    valueStreamPath() {
      const { selectedValueStream, vsaPath } = this;

      return selectedValueStream
        ? mergeUrlParams({ value_stream_id: selectedValueStream.id }, vsaPath)
        : vsaPath;
    },
  },
  created() {
    if (!this.defaultGroupLabels) {
      this.fetchGroupLabels();
    }
  },
  methods: {
    ...mapActions(['fetchGroupLabels']),
  },
};
</script>
<template>
  <div>
    <div v-if="isLoading" class="gl-pt-7 gl-text-center">
      <gl-loading-icon size="lg" />
    </div>
    <value-stream-form-content
      v-else
      :initial-data="initialData"
      :initial-form-errors="initialFormErrors"
      :default-stage-config="defaultStageConfig"
      :is-editing="isEditing"
      :value-stream-path="valueStreamPath"
    />
  </div>
</template>
