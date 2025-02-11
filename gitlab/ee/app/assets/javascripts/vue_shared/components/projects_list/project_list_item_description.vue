<script>
import { GlSprintf, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { SHORT_DATE_FORMAT } from '~/vue_shared/constants';
import { formatDate, newDate } from '~/lib/utils/datetime_utility';
import ProjectListItemDescriptionCe from '~/vue_shared/components/projects_list/project_list_item_description.vue';

export default {
  name: 'ProjectListItemDescriptionEE',
  i18n: {
    scheduledDeletion: s__('Projects|Scheduled for deletion on %{date}'),
  },
  components: {
    ProjectListItemDescriptionCe,
    GlSprintf,
    GlIcon,
  },
  props: {
    project: {
      type: Object,
      required: true,
    },
  },
  computed: {
    isPendingDeletion() {
      return Boolean(this.project.markedForDeletionOn);
    },
    formattedDate() {
      return formatDate(newDate(this.project.permanentDeletionDate), SHORT_DATE_FORMAT);
    },
  },
};
</script>

<template>
  <div v-if="isPendingDeletion" class="md gl-mt-2 gl-text-sm gl-text-secondary">
    <gl-icon name="calendar" />
    <gl-sprintf :message="$options.i18n.scheduledDeletion">
      <template #date>
        {{ formattedDate }}
      </template>
    </gl-sprintf>
  </div>
  <project-list-item-description-ce v-else :project="project" />
</template>
