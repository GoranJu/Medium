<script>
import { GlSprintf, GlFormRadioGroup, GlFormRadio } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import CascadingLockIcon from '~/namespaces/cascading_settings/components/cascading_lock_icon.vue';
import { AVAILABILITY_OPTIONS } from '../constants';

export default {
  name: 'DuoAvailabilityForm',
  i18n: {
    sectionTitle: __('Availability'),
    defaultOnText: s__('AiPowered|On by default'),
    defaultOnHelpText: s__(
      'AiPowered|Features are available. However, any group, subgroup, or project can turn them off.',
    ),
    defaultOffText: s__('AiPowered|Off by default'),
    defaultOffHelpText: s__(
      'AiPowered|Features are not available. However, any group, subgroup, or project can turn them on.',
    ),
    alwaysOffText: s__('AiPowered|Always off'),
    alwaysOffHelpText: s__(
      'AiPowered|Features are not available and cannot be turned on for any group, subgroup, or project.',
    ),
    defaultOnString: AVAILABILITY_OPTIONS.DEFAULT_ON,
    defaultOffString: AVAILABILITY_OPTIONS.DEFAULT_OFF,
    alwaysOffString: AVAILABILITY_OPTIONS.NEVER_ON,
  },
  components: {
    GlSprintf,
    GlFormRadioGroup,
    GlFormRadio,
    CascadingLockIcon,
  },
  inject: ['areDuoSettingsLocked', 'cascadingSettingsData'],
  props: {
    duoAvailability: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      duoAvailabilityState: this.duoAvailability,
    };
  },
  computed: {
    showCascadingButton() {
      return (
        this.areDuoSettingsLocked &&
        this.cascadingSettingsData &&
        Object.keys(this.cascadingSettingsData).length
      );
    },
  },
  methods: {
    radioChanged() {
      this.$emit('change', this.duoAvailabilityState);
    },
  },
};
</script>
<template>
  <div>
    <h5>{{ $options.i18n.sectionTitle }}</h5>
    <gl-form-radio-group v-model="duoAvailabilityState">
      <gl-form-radio
        :value="$options.i18n.defaultOnString"
        :disabled="areDuoSettingsLocked"
        @change="radioChanged"
      >
        {{ $options.i18n.defaultOnText }}
        <template #help>
          <gl-sprintf :message="$options.i18n.defaultOnHelpText" />
        </template>
      </gl-form-radio>
      <gl-form-radio
        :value="$options.i18n.defaultOffString"
        :disabled="areDuoSettingsLocked"
        @change="radioChanged"
      >
        {{ $options.i18n.defaultOffText }}
        <template #help>
          <gl-sprintf :message="$options.i18n.defaultOffHelpText" />
        </template>
      </gl-form-radio>
      <gl-form-radio
        :value="$options.i18n.alwaysOffString"
        :disabled="areDuoSettingsLocked"
        @change="radioChanged"
      >
        {{ $options.i18n.alwaysOffText }}
        <cascading-lock-icon
          v-if="showCascadingButton"
          :is-locked-by-group-ancestor="cascadingSettingsData.lockedByAncestor"
          :is-locked-by-application-settings="cascadingSettingsData.lockedByApplicationSetting"
          :ancestor-namespace="cascadingSettingsData.ancestorNamespace"
          class="gl-ml-1"
        />
        <template #help>
          <gl-sprintf :message="$options.i18n.alwaysOffHelpText" />
        </template>
      </gl-form-radio>
    </gl-form-radio-group>
  </div>
</template>
