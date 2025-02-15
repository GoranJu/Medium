<script>
import { GlAvatarLabeled, GlAvatarLink, GlAvatar, GlIcon, GlTooltipDirective } from '@gitlab/ui';
import { __ } from '~/locale';
import AssigneeTitle from '~/sidebar/components/assignees/assignee_title.vue';

export default {
  name: 'ExternalIssuesSidebarAssignee',
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlAvatar,
    GlIcon,
    AssigneeTitle,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    assignee: {
      type: Object,
      required: false,
      default: null,
    },
    avatarSubLabel: {
      type: String,
      required: false,
      default: null,
    },
  },
  computed: {
    tooltipTitle() {
      return this.assignee?.name || __('No assignee');
    },
    numberOfAssignees() {
      return this.assignee ? 1 : 0;
    },
  },
  tooltipOptions: {
    container: 'body',
    placement: 'left',
    boundary: 'viewport',
  },
};
</script>

<template>
  <div>
    <div class="hide-collapsed">
      <assignee-title
        :number-of-assignees="numberOfAssignees"
        :editable="false"
        :changing="false"
      />
      <gl-avatar-link
        v-if="assignee"
        v-gl-tooltip="$options.tooltipOptions"
        target="_blank"
        :href="assignee.webUrl"
        :title="tooltipTitle"
      >
        <gl-avatar-labeled
          :size="32"
          :src="assignee.avatarUrl"
          :alt="assignee.name"
          :entity-name="assignee.name"
          :label="assignee.name"
          :sub-label="avatarSubLabel"
        />
      </gl-avatar-link>
      <div v-else class="gl-leading-1 gl-text-subtle" data-testid="no-assignee-text">
        {{ __('None') }}
      </div>
    </div>

    <div
      v-gl-tooltip="$options.tooltipOptions"
      class="sidebar-collapsed-icon"
      :title="tooltipTitle"
      data-testid="sidebar-collapsed-icon-wrapper"
    >
      <gl-avatar
        v-if="assignee"
        :size="24"
        :src="assignee.avatarUrl"
        :alt="assignee.name"
        :entity-name="assignee.name"
      />
      <gl-icon v-else name="user" data-testid="no-assignee-icon" />
    </div>
  </div>
</template>
