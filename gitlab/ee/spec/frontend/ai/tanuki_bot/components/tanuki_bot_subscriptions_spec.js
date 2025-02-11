import Vue from 'vue';
import VueApollo from 'vue-apollo';
import { createMockSubscription } from 'mock-apollo-client';
import AiResponseSubscription from 'ee/ai/tanuki_bot/components/tanuki_bot_subscriptions.vue';
import aiResponseSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response.subscription.graphql';
import aiResponseStreamSubscription from 'ee/graphql_shared/subscriptions/ai_completion_response_stream.subscription.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';

import {
  MOCK_USER_ID,
  GENERATE_MOCK_TANUKI_RES,
  MOCK_CHUNK_MESSAGE,
  MOCK_CLIENT_SUBSCRIPTION_ID,
} from '../mock_data';

Vue.use(VueApollo);

describe('Ai Response Subscriptions', () => {
  let wrapper;

  let mockSubscriptionComplete;
  let mockSubscriptionStream;
  let aiResponseSubscriptionHandler;
  let aiResponseStreamSubscriptionHandler;

  const createComponent = ({ propsData = {} } = {}) => {
    const apolloProvider = createMockApollo();

    apolloProvider.defaultClient.setRequestHandler(
      aiResponseSubscription,
      aiResponseSubscriptionHandler,
    );

    apolloProvider.defaultClient.setRequestHandler(
      aiResponseStreamSubscription,
      aiResponseStreamSubscriptionHandler,
    );

    wrapper = shallowMountExtended(AiResponseSubscription, {
      apolloProvider,
      propsData: {
        userId: MOCK_USER_ID,
        clientSubscriptionId: MOCK_CLIENT_SUBSCRIPTION_ID,
        ...propsData,
      },
    });
  };

  beforeEach(() => {
    mockSubscriptionComplete = createMockSubscription();
    mockSubscriptionStream = createMockSubscription();
    aiResponseSubscriptionHandler = jest.fn(() => mockSubscriptionComplete);
    aiResponseStreamSubscriptionHandler = jest.fn(() => mockSubscriptionStream);
  });

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.commands = [];
  });

  describe('Subscriptions', () => {
    it('passes the correct variables to the subscription queries', async () => {
      createComponent();
      await waitForPromises();

      expect(aiResponseSubscriptionHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: MOCK_USER_ID,
          aiAction: 'CHAT',
        }),
      );

      expect(aiResponseStreamSubscriptionHandler).toHaveBeenCalledWith(
        expect.objectContaining({
          userId: MOCK_USER_ID,
          clientSubscriptionId: MOCK_CLIENT_SUBSCRIPTION_ID,
        }),
      );
    });

    describe('aiCompletionResponseStream', () => {
      it('emits message stream event', async () => {
        const requestId = '123';
        const firstChunk = {
          data: { aiCompletionResponse: MOCK_CHUNK_MESSAGE('first chunk', 1, requestId) },
        };

        createComponent();
        await waitForPromises();

        // message chunk streaming in
        mockSubscriptionStream.next(firstChunk);
        await waitForPromises();

        const emittedEvents = wrapper.emitted('message-stream');
        expect(emittedEvents).toHaveLength(1);
        expect(emittedEvents[0]).toEqual([firstChunk.data.aiCompletionResponse]);
      });

      it('emits response-received event', async () => {
        const requestId = '123';
        const firstChunk = {
          data: { aiCompletionResponse: MOCK_CHUNK_MESSAGE('first chunk', 1, requestId) },
        };

        createComponent();
        await waitForPromises();

        // message chunk streaming in
        mockSubscriptionStream.next(firstChunk);
        await waitForPromises();

        const emittedEvents = wrapper.emitted('response-received');
        expect(emittedEvents).toHaveLength(1);
        expect(emittedEvents[0]).toEqual([requestId]);
      });
    });

    describe('aiCompletionResponse', () => {
      it('emits message event', async () => {
        const requestId = '123';
        const successResponse = {
          data: { aiCompletionResponse: GENERATE_MOCK_TANUKI_RES('', requestId) },
        };
        createComponent();
        await waitForPromises();

        // message chunk streaming in
        mockSubscriptionComplete.next(successResponse);
        await waitForPromises();

        const emittedEvents = wrapper.emitted('message');
        expect(emittedEvents).toHaveLength(1);
        expect(emittedEvents[0]).toEqual([successResponse.data.aiCompletionResponse]);
      });
    });
  });
});
