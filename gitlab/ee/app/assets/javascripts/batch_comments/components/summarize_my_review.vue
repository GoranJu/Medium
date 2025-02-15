<script>
import { GlButton } from '@gitlab/ui';
import { v4 as uuidv4 } from 'uuid';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { __ } from '~/locale';
import { createAlert } from '~/alert';
import { convertToGraphQLId } from '~/graphql_shared/utils';
import { TYPENAME_USER, TYPENAME_MERGE_REQUEST } from '~/graphql_shared/constants';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiSummarizeReviewMutation from '../graphql/summarize_review.mutation.graphql';

export default {
  apollo: {
    $subscribe: {
      // eslint-disable-next-line @gitlab/vue-no-undef-apollo-properties
      summarizeReview: {
        query: aiResponseSubscription,
        variables() {
          return {
            resourceId: this.resourceId,
            userId: convertToGraphQLId(TYPENAME_USER, window.gon.current_user_id),
            clientSubscriptionId: this.clientSubscriptionId,
          };
        },
        skip() {
          return !this.summarizeReviewLoading;
        },
        result({ data }) {
          const content = data.aiCompletionResponse?.content;
          const errors = data.aiCompletionResponse?.errors;

          if (errors?.length) {
            createAlert({ message: errors[0] });
            this.$emit('loading', false);
          } else if (content) {
            this.$emit('input', content);
            this.$emit('loading', false);
          }
        },
      },
    },
  },
  components: {
    GlButton,
  },
  model: {
    prop: 'summarizeReviewLoading',
    event: 'loading',
  },
  props: {
    id: {
      required: true,
      type: Number,
    },
    summarizeReviewLoading: {
      type: Boolean,
      required: true,
    },
  },
  data() {
    return {
      clientSubscriptionId: uuidv4(),
    };
  },
  computed: {
    resourceId() {
      return convertToGraphQLId(TYPENAME_MERGE_REQUEST, this.id);
    },
  },
  methods: {
    triggerAiMutation() {
      this.$emit('loading', true);

      try {
        this.$apollo.mutate({
          mutation: aiSummarizeReviewMutation,
          variables: {
            resourceId: this.resourceId,
            clientSubscriptionId: this.clientSubscriptionId,
          },
        });
      } catch (e) {
        Sentry.captureException(e);

        createAlert({
          message: __('There was an error summarizing your pending comments.'),
          primaryButton: {
            text: __('Try again'),
            clickHandler: () => this.triggerAiMutation(),
          },
        });

        this.$emit('loading', false);
      }
    },
  },
};
</script>

<template>
  <gl-button
    icon="tanuki-ai"
    :disabled="summarizeReviewLoading"
    category="tertiary"
    size="small"
    data-testid="mutation-trigger"
    @click="triggerAiMutation"
  >
    {{ __('Add summary') }}
  </gl-button>
</template>
