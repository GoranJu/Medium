<script>
import { GlFormGroup, GlFormInput } from '@gitlab/ui';
import { i18n, ADDITIONAL_DEFAULT_STAGE_EVENTS } from './constants';
import StageFieldActions from './stage_field_actions.vue';

const findStageEvent = (stageEvents = [], eid = null) => {
  if (!eid) return '';
  return stageEvents.find(({ identifier }) => identifier === eid);
};

const eventIdToName = (stageEvents = [], eid) => {
  const event = findStageEvent(stageEvents, eid);
  return event?.name || '';
};

export default {
  name: 'DefaultStageFields',
  components: {
    StageFieldActions,
    GlFormGroup,
    GlFormInput,
  },
  props: {
    index: {
      type: Number,
      required: true,
    },
    stageLabel: {
      type: String,
      required: true,
    },
    totalStages: {
      type: Number,
      required: true,
    },
    stage: {
      type: Object,
      required: true,
    },
    errors: {
      type: Object,
      required: false,
      default: () => ({}),
    },
    stageEvents: {
      type: Array,
      required: true,
    },
  },
  methods: {
    isValid(field) {
      return !this.errors[field] || !this.errors[field]?.length;
    },
    renderError(field) {
      return this.errors[field] ? this.errors[field]?.join('\n') : null;
    },
    eventName(eventId) {
      return eventIdToName([...this.stageEvents, ...ADDITIONAL_DEFAULT_STAGE_EVENTS], eventId);
    },
  },
  i18n,
};
</script>
<template>
  <div class="gl-mb-4" data-testid="value-stream-stage-fields">
    <div class="gl-flex gl-flex-col sm:gl-flex-row">
      <div class="gl-mr-2 gl-grow">
        <gl-form-group
          :label="stageLabel"
          :state="isValid('name')"
          :invalid-feedback="renderError('name')"
          :data-testid="`default-stage-name-${index}`"
          :description="$options.i18n.DEFAULT_STAGE_FEATURES"
        >
          <!-- eslint-disable vue/no-mutating-props -->
          <gl-form-input
            v-model.trim="stage.name"
            :name="`create-value-stream-stage-${index}`"
            :placeholder="$options.i18n.FORM_FIELD_STAGE_NAME_PLACEHOLDER"
            disabled="disabled"
            required
          />
          <!-- eslint-enable vue/no-mutating-props -->
        </gl-form-group>
        <div class="gl-flex gl-items-center" :data-testid="`stage-start-event-${index}`">
          <span class="gl-mr-2 gl-font-bold">{{
            $options.i18n.DEFAULT_FIELD_START_EVENT_LABEL
          }}</span>
          <span>{{ eventName(stage.startEventIdentifier) }}</span>
        </div>
        <div class="gl-flex gl-items-center" :data-testid="`stage-end-event-${index}`">
          <span class="gl-mr-2 gl-font-bold">{{
            $options.i18n.DEFAULT_FIELD_END_EVENT_LABEL
          }}</span>
          <span>{{ eventName(stage.endEventIdentifier) }}</span>
        </div>
      </div>
      <stage-field-actions
        class="gl-mt-3 sm:!gl-mt-6"
        :index="index"
        :stage-count="totalStages"
        @move="$emit('move', $event)"
        @hide="$emit('hide', $event)"
      />
    </div>
  </div>
</template>
