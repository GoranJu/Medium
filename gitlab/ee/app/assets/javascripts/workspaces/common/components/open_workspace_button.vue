<script>
import { GlButton, GlTooltipDirective } from '@gitlab/ui';
import { WORKSPACE_STATES } from '../constants';

export default {
  components: {
    GlButton,
  },
  directives: {
    GlTooltip: GlTooltipDirective,
  },
  props: {
    workspaceDisplayState: {
      type: String,
      required: true,
      validator: (value) => Object.values(WORKSPACE_STATES).includes(value),
    },
    workspaceUrl: {
      type: String,
      required: false,
      default: '',
    },
  },
  computed: {
    displayOpenWorkspaceButton() {
      return this.workspaceDisplayState === WORKSPACE_STATES.running && this.workspaceUrl !== '';
    },
    displayStartingWorkspaceIndicator() {
      return [WORKSPACE_STATES.creationRequested, WORKSPACE_STATES.starting].includes(
        this.workspaceDisplayState,
      );
    },
  },
};
</script>
<template>
  <span>
    <gl-button
      v-if="displayOpenWorkspaceButton"
      :href="workspaceUrl"
      class="gl-w-full sm:gl-w-auto"
      data-testid="workspace-open-button"
      target="_blank"
    >
      {{ s__('Workspaces|Open workspace') }}
    </gl-button>
    <span
      v-if="displayStartingWorkspaceIndicator"
      v-gl-tooltip
      :title="s__('Workspaces|You can open the workspace only once it is ready.')"
    >
      <gl-button loading>
        {{ s__('Workspaces|Starting workspace') }}
      </gl-button>
    </span>
  </span>
</template>
