<script>
import EventItem from 'ee/vue_shared/security_reports/components/event_item.vue';
import HistoryComment from './history_comment.vue';

export default {
  components: {
    EventItem,
    HistoryComment,
  },
  props: {
    discussion: {
      type: Object,
      required: true,
    },
  },
  computed: {
    notes() {
      return this.discussion.notes;
    },
    systemNote() {
      return this.notes.find((x) => x.system === true);
    },
    comments() {
      return this.notes.filter((x) => x !== this.systemNote);
    },
  },
};
</script>

<template>
  <div v-if="systemNote" class="card system-note gl-border-b gl-p-0">
    <event-item
      :id="systemNote.id"
      :author="systemNote.author"
      :created-at="systemNote.createdAt"
      :icon-name="systemNote.systemNoteIconName"
      is-system-note
      icon-class="timeline-icon"
      class="gl-m-5"
    >
      <template #header-message>{{ systemNote.body }}</template>
    </event-item>
    <history-comment
      v-for="comment in comments"
      :key="comment.id"
      :comment="comment"
      :discussion-id="discussion.replyId"
      data-testid="existing-comment"
      v-on="$listeners"
    />
    <history-comment
      v-if="!comments.length"
      :discussion-id="discussion.replyId"
      data-testid="new-comment"
      v-on="$listeners"
    />
  </div>
</template>
