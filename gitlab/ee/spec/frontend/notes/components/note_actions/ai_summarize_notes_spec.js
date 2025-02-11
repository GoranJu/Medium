import Vue, { nextTick } from 'vue';
import VueApollo from 'vue-apollo';
import { GlButton } from '@gitlab/ui';
import { BV_HIDE_TOOLTIP } from '~/lib/utils/constants';
import createMockApollo from 'helpers/mock_apollo_helper';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import * as aiUtils from 'ee/ai/utils';
import AiSummaryNotes from 'ee/notes/components/note_actions/ai_summarize_notes.vue';
import aiActionMutation from 'ee/graphql_shared/mutations/ai_action.mutation.graphql';

Vue.use(VueApollo);
jest.mock('ee/ai/utils');
jest.spyOn(aiUtils, 'sendDuoChatCommand');

describe('AiSummarizeNotes component', () => {
  let wrapper;
  let aiActionMutationHandler;
  const resourceGlobalId = 'gid://gitlab/Issue/1';
  const clientSubscriptionId = 'someId';

  const findButton = () => wrapper.findComponent(GlButton);

  const createWrapper = () => {
    aiActionMutationHandler = jest.fn();

    const mockApollo = createMockApollo([[aiActionMutation, aiActionMutationHandler]]);

    wrapper = mountExtended(AiSummaryNotes, {
      apolloProvider: mockApollo,
      provide: {
        summarizeClientSubscriptionId: clientSubscriptionId,
        glAbilities: {
          summarizeComments: true,
        },
      },
      propsData: {
        resourceGlobalId,
      },
    });
  };

  describe('on click', () => {
    it('calls sendDuoChatCommand with correct variables', async () => {
      createWrapper();

      await findButton().trigger('click');
      await nextTick();

      expect(aiUtils.sendDuoChatCommand).toHaveBeenCalledWith({
        question: '/summarize_comments',
        resourceId: resourceGlobalId,
      });
    });

    it('closes tooltip', async () => {
      createWrapper();

      const bsTooltipHide = jest.fn();
      wrapper.vm.$root.$on(BV_HIDE_TOOLTIP, bsTooltipHide);

      await findButton().trigger('click');
      await nextTick();

      expect(bsTooltipHide).toHaveBeenCalled();
    });
  });

  describe('on mouseout', () => {
    let bsTooltipHide;

    beforeEach(async () => {
      createWrapper();

      bsTooltipHide = jest.fn();
      wrapper.vm.$root.$on(BV_HIDE_TOOLTIP, bsTooltipHide);

      await findButton().trigger('mouseout');
      await nextTick();
    });

    it('closes tooltip', () => {
      expect(bsTooltipHide).toHaveBeenCalled();
    });
  });
});
