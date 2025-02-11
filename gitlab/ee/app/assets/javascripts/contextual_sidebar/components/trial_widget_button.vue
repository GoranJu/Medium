<script>
import { GlLink } from '@gitlab/ui';
import { snakeCase } from 'lodash';
import HandRaiseLeadButton from 'ee/hand_raise_leads/hand_raise_lead/components/hand_raise_lead_button.vue';
import { InternalEvents } from '~/tracking';
import {
  TRIAL_TYPES_CONFIG,
  TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS,
  TRIAL_WIDGET_CLICK_LEARN_MORE,
  TRIAL_WIDGET_CLICK_UPGRADE,
} from './constants';

export default {
  name: 'TrialWidgetButton',
  handRaiseLeadAttributes: {
    variant: 'link',
    category: 'tertiary',
    size: 'small',
  },
  components: {
    GlLink,
    HandRaiseLeadButton,
  },
  mixins: [InternalEvents.mixin()],
  inject: {
    trialType: { default: '' },
    daysRemaining: { default: 0 },
    purchaseNowUrl: { default: '' },
    trialDiscoverPagePath: { default: '' },
  },
  computed: {
    isBeforeUpgradeThreshold() {
      return TRIAL_WIDGET_UPGRADE_THRESHOLD_DAYS < this.daysRemaining;
    },
    useHandRaiseLead() {
      return this.trialType !== 'duo_pro';
    },
    handRaiseLeadTracking() {
      return {
        category: 'trial_widget',
        action: 'click_button',
        label: `${this.trialType}_contact_sales`,
      };
    },
    trackingLabel() {
      return snakeCase(TRIAL_TYPES_CONFIG[this.trialType].name.toLowerCase());
    },
  },
  methods: {
    handleUpgrade() {
      this.trackEvent(TRIAL_WIDGET_CLICK_UPGRADE, {
        label: this.trackingLabel,
      });
    },
    handleLearnMore() {
      this.trackEvent(TRIAL_WIDGET_CLICK_LEARN_MORE, {
        label: this.trackingLabel,
      });
    },
  },
};
</script>

<template>
  <gl-link
    v-if="isBeforeUpgradeThreshold"
    :href="trialDiscoverPagePath"
    class="gl-text-sm gl-font-bold gl-no-underline hover:gl-no-underline"
    size="small"
    data-testid="learn-about-features-btn"
    @click.stop="handleLearnMore"
  >
    {{ s__('TrialWidget|Learn more') }}
  </gl-link>
  <hand-raise-lead-button
    v-else-if="useHandRaiseLead"
    :button-attributes="$options.handRaiseLeadAttributes"
    :button-text="s__('TrialWidget|Upgrade')"
    :cta-tracking="handRaiseLeadTracking"
    glm-content="trial-widget-upgrade-button"
    data-testid="cta-hand-raise-lead-btn"
    class="gl-font-bold"
  />
  <gl-link
    v-else
    :href="purchaseNowUrl"
    class="gl-text-sm gl-font-bold gl-no-underline hover:gl-no-underline"
    size="small"
    data-testid="upgrade-options-btn"
    @click.stop="handleUpgrade"
  >
    {{ s__('TrialWidget|Upgrade') }}
  </gl-link>
</template>
