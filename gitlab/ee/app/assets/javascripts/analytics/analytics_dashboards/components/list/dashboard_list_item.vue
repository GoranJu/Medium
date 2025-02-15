<script>
import { v4 as uuidv4 } from 'uuid';

import { GlIcon, GlBadge, GlLink, GlTruncateText, GlDisclosureDropdown } from '@gitlab/ui';
import { visitUrl, joinPaths } from '~/lib/utils/url_utility';
import { __ } from '~/locale';
import { DASHBOARD_STATUS_BETA } from '~/vue_shared/components/customizable_dashboard/constants';

const TRUNCATE_BUTTON_ID = `desc-truncate-btn-${uuidv4()}`;

export default {
  name: 'DashboardsListItem',
  components: {
    GlIcon,
    GlBadge,
    GlLink,
    GlTruncateText,
    GlDisclosureDropdown,
  },
  props: {
    dashboard: {
      type: Object,
      required: true,
    },
    showUserActions: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      dropdownItems: [
        {
          name: __('More actions'),
          items: [
            {
              text: __('Clone'),
              icon: 'duplicate',
              action: () => this.$emit('clone', this.dashboard.slug),
            },
          ],
        },
      ],
    };
  },
  computed: {
    isBuiltInDashboard() {
      return 'userDefined' in this.dashboard && !this.dashboard.userDefined;
    },
    showBetaBadge() {
      return this.dashboard?.status === DASHBOARD_STATUS_BETA;
    },
    showErrorsBadge() {
      return this.dashboard?.errors?.length > 0;
    },
    redirectHref() {
      return joinPaths(window.location.pathname, this.dashboard.slug);
    },
  },
  methods: {
    elementsTargeted(target, ...elements) {
      return elements.some((element) => element === target || element?.contains(target));
    },
    routeToDashboard(e) {
      const dropdownBtn = this.$refs.dropdown?.$el;
      const truncateToggleBtn = document.getElementById(TRUNCATE_BUTTON_ID);

      if (this.elementsTargeted(e.target, dropdownBtn, truncateToggleBtn)) return;

      if (this.dashboard.redirect) {
        visitUrl(this.redirectHref);
      } else {
        this.$router.push(this.dashboard.slug);
      }
    },
  },
  truncateTextToggleButtonProps: { id: TRUNCATE_BUTTON_ID },
};
</script>

<template>
  <li
    class="!gl-flex gl-items-center !gl-px-5 hover:gl-cursor-pointer hover:gl-bg-blue-50"
    data-testid="dashboard-list-item"
    @click="routeToDashboard"
  >
    <div class="gl-float-left gl-mr-4 gl-flex gl-items-center">
      <gl-icon name="dashboard" class="gl-mr-3" :size="16" variant="disabled" />
    </div>
    <div class="gl-flex gl-grow gl-items-center gl-justify-between">
      <div class="gl-flex gl-flex-col">
        <div class="gl-flex gl-items-center">
          <gl-link
            v-if="dashboard.redirect"
            data-testid="dashboard-redirect-link"
            :href="redirectHref"
            class="gl-font-bold gl-leading-normal !gl-no-underline"
            >{{ dashboard.title }}</gl-link
          >
          <router-link
            v-else
            data-testid="dashboard-router-link"
            class="gl-font-bold gl-leading-normal"
            :to="dashboard.slug"
            >{{ dashboard.title }}</router-link
          >
          <gl-badge v-if="showBetaBadge" data-testid="dashboard-beta-badge" class="gl-ml-2">
            {{ __('Beta') }}
          </gl-badge>
          <gl-badge
            v-if="showErrorsBadge"
            data-testid="dashboard-errors-badge"
            class="gl-ml-2"
            icon="error"
            icon-size="sm"
            variant="danger"
          >
            {{ __('Contains errors') }}
          </gl-badge>
        </div>
        <gl-truncate-text
          class="gl-text-subtle"
          :toggle-button-props="$options.truncateTextToggleButtonProps"
        >
          {{ dashboard.description }}
        </gl-truncate-text>
      </div>
      <div class="gl-float-right gl-flex gl-items-baseline gl-gap-3">
        <div>
          <gl-badge
            v-if="isBuiltInDashboard"
            variant="muted"
            icon="tanuki-verified"
            data-testid="dashboard-by-gitlab"
            >{{ s__('Analytics|Created by GitLab') }}</gl-badge
          >
        </div>
        <gl-disclosure-dropdown
          v-if="showUserActions"
          ref="dropdown"
          data-testid="dashboard-actions-dropdown"
          icon="ellipsis_v"
          :toggle-text="__('More actions')"
          text-sr-only
          :items="dropdownItems"
          category="tertiary"
          no-caret
        >
          <template #list-item="{ item }">
            <span class="gl-flex gl-items-center gl-gap-3">
              <gl-icon :name="item.icon" variant="subtle" />
              {{ item.text }}
            </span>
          </template>
        </gl-disclosure-dropdown>
      </div>
    </div>
  </li>
</template>
