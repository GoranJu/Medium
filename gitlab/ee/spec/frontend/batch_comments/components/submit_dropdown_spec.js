import Vue from 'vue';
import VueApollo from 'vue-apollo';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { GlDisclosureDropdown } from '@gitlab/ui';
import { createTestingPinia } from '@pinia/testing';
import { PiniaVuePlugin } from 'pinia';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import SubmitDropdown from '~/batch_comments/components/submit_dropdown.vue';
import userCanApproveQuery from '~/batch_comments/queries/can_approve.query.graphql';
import { updateText } from '~/lib/utils/text_markdown';
import SummarizeMyReview from 'ee/batch_comments/components/summarize_my_review.vue';
import { globalAccessorPlugin } from '~/pinia/plugins';
import { useLegacyDiffs } from '~/diffs/stores/legacy_diffs';
import { useNotes } from '~/notes/store/legacy_notes';
import { useBatchComments } from '~/batch_comments/store';

jest.mock('~/lib/utils/text_markdown');

Vue.use(Vuex);
Vue.use(VueApollo);
Vue.use(PiniaVuePlugin);

let wrapper;
let pinia;
let publishReview;

function factory({
  canApprove = true,
  requirePasswordToApprove = true,
  canSummarize = false,
} = {}) {
  publishReview = jest.fn();
  const requestHandlers = [
    [
      userCanApproveQuery,
      () =>
        Promise.resolve({
          data: {
            project: {
              id: 1,
              mergeRequest: {
                id: 1,
                userPermissions: {
                  canApprove,
                },
              },
            },
          },
        }),
    ],
  ];
  const apolloProvider = createMockApollo(requestHandlers);

  const store = new Vuex.Store({
    getters: {
      getNotesData: () => ({
        markdownDocsPath: '/markdown/docs',
        quickActionsDocsPath: '/quickactions/docs',
      }),
      getNoteableData: () => ({
        id: 1,
        preview_note_path: '/preview',
        require_password_to_approve: requirePasswordToApprove,
      }),
      noteableType: () => 'merge_request',
    },
    modules: {
      diffs: {
        namespaced: true,
        state: {
          projectPath: 'gitlab-org/gitlab',
        },
      },
      batchComments: {
        namespaced: true,
        actions: {
          publishReview,
        },
      },
    },
  });
  wrapper = mountExtended(SubmitDropdown, {
    store,
    pinia,
    apolloProvider,
    stubs: { SummarizeMyReview },
    provide: { canSummarize },
  });
}

describe('Batch comments submit dropdown', () => {
  beforeEach(() => {
    pinia = createTestingPinia({ plugins: [globalAccessorPlugin] });
    useLegacyDiffs();
    useNotes();
    useBatchComments();
  });

  it.each`
    requirePasswordToApprove | exists   | existsText
    ${true}                  | ${true}  | ${'shows'}
    ${false}                 | ${false} | ${'hides'}
  `(
    '$existsText approve password if require_password_to_approve is $requirePasswordToApprove',
    async ({ requirePasswordToApprove, exists }) => {
      factory({ requirePasswordToApprove });

      wrapper.findComponent(GlDisclosureDropdown).vm.$emit('shown');

      await waitForPromises();

      expect(wrapper.findByTestId('approve_password').exists()).toBe(exists);
    },
  );

  describe('AI summarize my review', () => {
    it('calls updateText with the AI content', () => {
      factory({ canSummarize: true });

      wrapper.findComponent(SummarizeMyReview).vm.$emit('input', 'AI review content');

      expect(updateText).toHaveBeenCalledWith(
        expect.objectContaining({
          tag: 'AI review content',
        }),
      );
    });
  });
});
