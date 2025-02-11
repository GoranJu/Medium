<script>
import {
  GlBadge,
  GlFormGroup,
  GlFormRadio,
  GlFormRadioGroup,
  GlFormInput,
  GlSprintf,
} from '@gitlab/ui';
import HelpPageLink from '~/vue_shared/components/help_page_link/help_page_link.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import { SEAT_CONTROL } from 'ee/pages/admin/application_settings/general/constants';
import SeatControlMemberPromotionManagement from 'ee_component/pages/admin/application_settings/general/components/seat_control_member_promotion_management.vue';

export default {
  name: 'SeatControlsSection',
  components: {
    GlBadge,
    GlFormGroup,
    GlFormRadio,
    GlFormRadioGroup,
    GlFormInput,
    GlSprintf,
    HelpPageLink,
    SeatControlMemberPromotionManagement,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['licensedUserCount', 'newUserSignupsCap', 'promotionManagementAvailable', 'seatControl'],
  data() {
    return {
      userCap: this.newUserSignupsCap,
      seatControlSettings: this.seatControl,
    };
  },
  computed: {
    hasUserCapBeenIncreased() {
      if (this.hasUserCapChangedFromUnlimitedToLimited) return false;
      if (this.hasUserCapChangedFromLimitedToUnlimited) return true;

      const oldValueAsInteger = parseInt(this.newUserSignupsCap, 10);
      const newValueAsInteger = parseInt(this.userCap, 10);

      return newValueAsInteger > oldValueAsInteger;
    },
    hasUserCapChangedFromLimitedToUnlimited() {
      return !this.isOldUserCapUnlimited && this.isNewUserCapUnlimited;
    },
    hasUserCapChangedFromUnlimitedToLimited() {
      return this.isOldUserCapUnlimited && !this.isNewUserCapUnlimited;
    },
    isBlockOveragesEnabled() {
      return this.seatControlSettings === SEAT_CONTROL.BLOCK_OVERAGES;
    },
    isNewUserCapUnlimited() {
      // The current value of User Cap is unlimited if no value is provided in the field
      return this.userCap === '';
    },
    isOldUserCapUnlimited() {
      // The previous/initial value of User Cap is unlimited if it was empty
      return this.newUserSignupsCap === '';
    },
    isUserCapEnabled() {
      return parseInt(this.seatControlSettings, 10) === SEAT_CONTROL.USER_CAP;
    },
    shouldShowSeatControlSection() {
      // This actually refers to a licensed feature. See https://gitlab.com/gitlab-org/gitlab/-/issues/322460
      return Boolean(this.glFeatures.seatControl);
    },
    shouldVerifyUsersAutoApproval() {
      if (this.isBlockOveragesEnabled) return false;

      return this.hasUserCapBeenIncreased;
    },
  },
  methods: {
    handleSeatControlSettingsChange(seatControl) {
      this.seatControlSettings = seatControl;
      this.userCap = this.isUserCapEnabled ? this.userCap : '';
      this.$emit('checkUsersAutoApproval', this.shouldVerifyUsersAutoApproval);
    },
    handleUserCapChange(userCap) {
      this.userCap = userCap;
      this.$emit('checkUsersAutoApproval', this.shouldVerifyUsersAutoApproval);
    },
  },
  SEAT_CONTROL,
};
</script>

<template>
  <div v-if="shouldShowSeatControlSection">
    <gl-form-group :label="s__('ApplicationSettings|Seat control')">
      <gl-form-radio-group
        :checked="seatControl"
        name="application_setting[seat_control]"
        @change="handleSeatControlSettingsChange"
      >
        <gl-form-radio
          :value="$options.SEAT_CONTROL.BLOCK_OVERAGES"
          data-testid="seat-control-restricted-access"
        >
          {{ s__('ApplicationSettings|Restricted access') }}
          <gl-badge variants="neutral" class="gl-ml-2">{{ __('Beta') }}</gl-badge>
          <template #help>{{
            s__(
              'ApplicationSettings|New users cannot be added or request access. Restricts the occurrence of seat overages.',
            )
          }}</template>
        </gl-form-radio>

        <gl-form-radio :value="$options.SEAT_CONTROL.USER_CAP" data-testid="seat-control-user-cap">
          {{ s__('ApplicationSettings|Controlled access') }}
          <template #help>{{
            s__(
              'ApplicationSettings|Administrator approval required for new users. Set a user cap for the maximum number of users who can be added without administrator approval.',
            )
          }}</template>
        </gl-form-radio>

        <div class="gl-ml-6 gl-mt-3">
          <gl-form-group
            id="user-cap-input-group"
            data-testid="user-cap-group"
            :label="__('Set user cap')"
            label-for="user-cap-input"
            label-sr-only
          >
            <gl-form-input
              id="user-cap-input"
              v-model="userCap"
              type="text"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input"
              :disabled="!isUserCapEnabled"
              @input="handleUserCapChange"
            />
            <input
              type="hidden"
              name="application_setting[new_user_signups_cap]"
              data-testid="user-cap-input-hidden"
              :disabled="isUserCapEnabled"
              :value="userCap"
            />
            <small class="form-text text-muted">
              {{
                s__(
                  'ApplicationSettings|Users added beyond this limit require administrator approval. Leave blank for unlimited.',
                )
              }}
              <gl-sprintf
                v-if="licensedUserCount"
                :message="
                  s__(
                    'ApplicationSettings|A user cap that exceeds the current licensed user count (%{licensedUserCount}) may result in a %{linkStart}true-up%{linkEnd}.',
                  )
                "
              >
                <template #licensedUserCount>{{ licensedUserCount }}</template>
                <template #link="{ content }">
                  <help-page-link
                    href="subscriptions/quarterly_reconciliation"
                    anchor="quarterly-reconciliation-versus-annual-true-ups"
                    >{{ content }}</help-page-link
                  >
                </template>
              </gl-sprintf>
            </small>
          </gl-form-group>
        </div>

        <gl-form-radio :value="$options.SEAT_CONTROL.OFF" data-testid="seat-control-open-access">
          {{ s__('ApplicationSettings|Open access') }}
          <template #help>{{
            s__('ApplicationSettings|Administrator approval not required for new users.')
          }}</template>
        </gl-form-radio>
      </gl-form-radio-group>
    </gl-form-group>

    <gl-form-group
      v-if="promotionManagementAvailable"
      :label="s__('ApplicationSettings|Role Promotions')"
    >
      <seat-control-member-promotion-management />
    </gl-form-group>
  </div>
</template>
