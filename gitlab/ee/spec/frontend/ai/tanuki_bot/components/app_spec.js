import { DuoChat } from '@gitlab/duo-ui';
import Vue, { nextTick } from 'vue';
import { v4 as uuidv4 } from 'uuid';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import VueApollo from 'vue-apollo';
import { sendDuoChatCommand } from 'ee/ai/utils';
import TanukiBotChatApp from 'ee/ai/tanuki_bot/components/app.vue';
import DuoChatCallout from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import TanukiBotSubscriptions from 'ee/ai/tanuki_bot/components/tanuki_bot_subscriptions.vue';
import { GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE } from 'ee/ai/constants';
import { TANUKI_BOT_TRACKING_EVENT_NAME, WIDTH_OFFSET } from 'ee/ai/tanuki_bot/constants';
import chatMutation from 'ee/ai/graphql/chat.mutation.graphql';
import duoUserFeedbackMutation from 'ee/ai/graphql/duo_user_feedback.mutation.graphql';
import getAiMessages from 'ee/ai/graphql/get_ai_messages.query.graphql';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import createMockApollo from 'helpers/mock_apollo_helper';
import { getMarkdown } from '~/rest_api';
import { mockTracking, unmockTracking } from 'helpers/tracking_helper';
import waitForPromises from 'helpers/wait_for_promises';
import { duoChatGlobalState } from '~/super_sidebar/constants';
import { describeSkipVue3, SkipReason } from 'helpers/vue3_conditional';
import getAiSlashCommands from 'ee/ai/graphql/get_ai_slash_commands.query.graphql';

import {
  MOCK_USER_MESSAGE,
  MOCK_USER_ID,
  MOCK_RESOURCE_ID,
  MOCK_CHUNK_MESSAGE,
  MOCK_TANUKI_BOT_MUTATATION_RES,
  GENERATE_MOCK_TANUKI_RES,
  MOCK_CHAT_CACHED_MESSAGES_RES,
  MOCK_SLASH_COMMANDS,
} from '../mock_data';

Vue.use(Vuex);
Vue.use(VueApollo);

jest.mock('~/rest_api');
jest.mock('uuid');

const skipReason = new SkipReason({
  name: 'GitLab Duo Chat',
  reason: 'Test times out (CPU pegged at 100%)',
  issue: 'https://gitlab.com/gitlab-org/gitlab/-/issues/458409',
});

describeSkipVue3(skipReason, () => {
  let wrapper;

  const UUIDMOCK = '123';

  const actionSpies = {
    addDuoChatMessage: jest.fn(),
    setMessages: jest.fn(),
    setLoading: jest.fn(),
  };

  const chatMutationHandlerMock = jest.fn().mockResolvedValue(MOCK_TANUKI_BOT_MUTATATION_RES);
  const duoUserFeedbackMutationHandlerMock = jest.fn().mockResolvedValue({});
  const queryHandlerMock = jest.fn().mockResolvedValue(MOCK_CHAT_CACHED_MESSAGES_RES);
  const slashCommandsQueryHandlerMock = jest.fn().mockResolvedValue(MOCK_SLASH_COMMANDS);

  const feedbackData = {
    feedbackChoices: ['useful', 'not_relevant'],
    didWhat: 'provided clarity',
    improveWhat: 'more examples',
    message: {
      requestId: '1234567890',
      id: 'abcdefgh',
      role: 'user',
      content: 'test',
      extras: {
        exampleExtraContent: 1,
      },
    },
  };

  const findCallout = () => wrapper.findComponent(DuoChatCallout);
  const findSubscriptions = () => wrapper.findComponent(TanukiBotSubscriptions);

  const createComponent = ({
    initialState = {},
    propsData = { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID },
    glFeatures = { duoChatDynamicDimension: false },
  } = {}) => {
    const store = new Vuex.Store({
      actions: actionSpies,
      state: {
        ...initialState,
      },
    });

    const apolloProvider = createMockApollo([
      [chatMutation, chatMutationHandlerMock],
      [duoUserFeedbackMutation, duoUserFeedbackMutationHandlerMock],
      [getAiMessages, queryHandlerMock],
      [getAiSlashCommands, slashCommandsQueryHandlerMock],
    ]);

    wrapper = shallowMountExtended(TanukiBotChatApp, {
      store,
      apolloProvider,
      propsData,
      provide: {
        glFeatures,
      },
    });
  };

  const findDuoChat = () => wrapper.findComponent(DuoChat);

  beforeEach(() => {
    uuidv4.mockImplementation(() => UUIDMOCK);
    getMarkdown.mockImplementation(({ text }) => Promise.resolve({ data: { html: text } }));
  });

  afterEach(() => {
    jest.clearAllMocks();
    duoChatGlobalState.commands = [];
    duoChatGlobalState.isShown = false;
  });

  it('generates unique `clientSubscriptionId` using v4', () => {
    createComponent();
    expect(uuidv4).toHaveBeenCalled();
    expect(wrapper.vm.clientSubscriptionId).toBe('123');
  });

  describe('fetching the cached messages', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = true;
      });

      it('fetches the cached messages on mount and updates the messages with the returned result', async () => {
        createComponent();
        expect(queryHandlerMock).toHaveBeenCalled();
        await waitForPromises();
        expect(actionSpies.setMessages).toHaveBeenCalledWith(
          expect.anything(),
          MOCK_CHAT_CACHED_MESSAGES_RES.data.aiMessages.nodes,
        );
      });

      it('updates the messages even if the returned result has no messages', async () => {
        queryHandlerMock.mockResolvedValue({
          data: {
            aiMessages: {
              nodes: [],
            },
          },
        });
        createComponent();
        await waitForPromises();
        expect(actionSpies.setMessages).toHaveBeenCalledWith(expect.anything(), []);
      });
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = false;
      });

      it('does not fetch cached messages', () => {
        createComponent();
        expect(queryHandlerMock).not.toHaveBeenCalled();
      });
    });
  });

  describe('rendering', () => {
    describe('when Duo Chat is shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isShown = true;
      });

      it('renders the DuoChat component', () => {
        expect(findDuoChat().exists()).toBe(true);
      });

      it('sets correct `badge-type` and `badge-help-page-url` props on the chat component', () => {
        expect(findDuoChat().props('badgeType')).toBe(null);
      });

      it('calls the slash commands GraphQL query when component loads', () => {
        expect(slashCommandsQueryHandlerMock).toHaveBeenCalledWith({
          url: 'http://test.host/',
        });
      });

      it('passes the correct slash commands to the DuoChat component', async () => {
        await waitForPromises();

        const duoChat = findDuoChat();

        expect(duoChat.props('slashCommands')).toEqual([
          {
            description: 'Reset conversation and ignore previous messages.',
            name: '/reset',
            shouldSubmit: true,
          },
          {
            description: 'Delete all messages in the current conversation.',
            name: '/clear',
            shouldSubmit: true,
          },
          {
            description: 'Learn what Duo Chat can do.',
            name: '/help',
            shouldSubmit: true,
          },
        ]);
      });

      it('renders the duo-chat-callout component', () => {
        expect(findCallout().exists()).toBe(true);
      });
    });

    describe('when Duo Chat is not shown', () => {
      beforeEach(() => {
        createComponent();
        duoChatGlobalState.isShown = false;
      });

      it('does not call the slash commands GraphQL query', () => {
        expect(slashCommandsQueryHandlerMock).not.toHaveBeenCalled();
      });

      it('does not render the DuoChat component', () => {
        expect(findDuoChat().exists()).toBe(false);
      });
    });
  });

  describe('when new commands are added to the global state', () => {
    beforeEach(() => {
      createComponent();
      mockTracking(undefined, wrapper.element, jest.spyOn);
      performance.mark = jest.fn();
    });

    it('calls the chat mutation', async () => {
      expect(chatMutationHandlerMock).toHaveBeenCalledTimes(0);

      sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
      await waitForPromises();

      expect(chatMutationHandlerMock).toHaveBeenCalledTimes(1);
    });

    it('uses the command resourceId', async () => {
      sendDuoChatCommand({ question: '/troubleshoot', resourceId: 'command::1' });
      await waitForPromises();

      expect(chatMutationHandlerMock).toHaveBeenCalledWith({
        clientSubscriptionId: '123',
        question: '/troubleshoot',
        resourceId: 'command::1',
        projectId: null,
      });
    });
  });

  describe('events handling', () => {
    beforeEach(() => {
      createComponent();
      duoChatGlobalState.isShown = true;
    });

    describe('@chat-hidden', () => {
      beforeEach(async () => {
        findDuoChat().vm.$emit('chat-hidden');
        await nextTick();
      });

      it('closes the chat on @chat-hidden', () => {
        expect(duoChatGlobalState.isShown).toBe(false);
        expect(findDuoChat().exists()).toBe(false);
      });
    });

    describe('@send-chat-prompt', () => {
      beforeEach(() => {
        mockTracking(undefined, wrapper.element, jest.spyOn);
        performance.mark = jest.fn();
      });

      afterEach(() => {
        unmockTracking();
      });

      it('does set loading to `true` for a message other than the reset or clear messages', () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        expect(actionSpies.setLoading).toHaveBeenCalled();
      });

      it('starts the performance measurement when sending a prompt', () => {
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        expect(performance.mark).toHaveBeenCalledWith('prompt-sent');
      });

      it('calls the chat mutation with projectId when available', async () => {
        createComponent({
          propsData: { userId: MOCK_USER_ID, resourceId: null, projectId: 'project-123' },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_USER_ID,
          projectId: 'project-123',
        });
      });

      it('calls the chat mutation without projectId if it is not provided', async () => {
        createComponent({
          propsData: { userId: MOCK_USER_ID, resourceId: MOCK_RESOURCE_ID, projectId: null },
        });

        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

        await nextTick();

        expect(chatMutationHandlerMock).toHaveBeenCalledWith({
          clientSubscriptionId: '123',
          question: MOCK_USER_MESSAGE.content,
          resourceId: MOCK_RESOURCE_ID,
          projectId: null,
        });
      });

      it.each([GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
        'does not set loading to `true` for "%s" message',
        async (msg) => {
          actionSpies.setLoading.mockReset();
          findDuoChat().vm.$emit('send-chat-prompt', msg);
          await nextTick();
          expect(actionSpies.setLoading).not.toHaveBeenCalled();
        },
      );

      describe.each`
        resourceId          | expectedResourceId
        ${MOCK_RESOURCE_ID} | ${MOCK_RESOURCE_ID}
        ${null}             | ${MOCK_USER_ID}
      `(`with resourceId = $resourceId`, ({ resourceId, expectedResourceId }) => {
        it('calls correct GraphQL mutation with fallback to userId when input is submitted', async () => {
          createComponent({ propsData: { userId: MOCK_USER_ID, resourceId } });
          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

          await nextTick();

          expect(chatMutationHandlerMock).toHaveBeenCalledWith({
            resourceId: expectedResourceId,
            question: MOCK_USER_MESSAGE.content,
            clientSubscriptionId: '123',
            projectId: null,
          });
        });
      });

      it.each([GENIE_CHAT_CLEAR_MESSAGE])(
        'refetches the `aiMessages` if the prompt is "%s" and does not call addDuoChatMessage',
        async (prompt) => {
          createComponent();

          await waitForPromises();

          queryHandlerMock.mockClear();
          actionSpies.addDuoChatMessage.mockClear();

          findDuoChat().vm.$emit('send-chat-prompt', prompt);

          await waitForPromises();

          expect(queryHandlerMock).toHaveBeenCalled();
          expect(actionSpies.addDuoChatMessage).not.toHaveBeenCalled();
        },
      );

      describe('tracking on mutation', () => {
        let trackingSpy;

        beforeEach(() => {
          trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
        });

        afterEach(() => {
          unmockTracking();
        });

        it('tracks the submission for prompts by default', async () => {
          createComponent();
          findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);

          await waitForPromises();
          expect(trackingSpy).toHaveBeenCalled();
        });
        it.each([GENIE_CHAT_RESET_MESSAGE, GENIE_CHAT_CLEAR_MESSAGE])(
          'does not track if the sent message is "%s"',
          async (msg) => {
            createComponent();
            findDuoChat().vm.$emit('send-chat-prompt', msg);

            await waitForPromises();
            expect(trackingSpy).not.toHaveBeenCalled();
          },
        );
      });
    });

    describe('@response-received', () => {
      let trackingSpy;
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, wrapper.element, jest.spyOn);
        performance.mark = jest.fn();
        performance.measure = jest.fn();
        performance.getEntriesByName = jest.fn(() => [{ duration: 123 }]);
        performance.clearMarks = jest.fn();
        performance.clearMeasures = jest.fn();
      });

      afterEach(() => {
        unmockTracking();
      });

      it('tracks time to response on first response-received', () => {
        findSubscriptions().vm.$emit('response-received', 'request-id-123');

        expect(performance.mark).toHaveBeenCalledWith('response-received');

        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'ai_response_time', {
          requestId: 'request-id-123',
          value: 123,
        });
      });

      it('does not track time to response after first chunk was tracked', () => {
        findSubscriptions().vm.$emit('response-received', 'request-id-123');
        findSubscriptions().vm.$emit('response-received', 'request-id-123');

        expect(performance.mark).toHaveBeenCalledTimes(1);
        expect(trackingSpy).toHaveBeenCalledTimes(1);
      });
    });

    describe('@track-feedback', () => {
      it('calls the feedback GraphQL mutation when message is passed', async () => {
        createComponent();
        findDuoChat().vm.$emit('track-feedback', feedbackData);

        await waitForPromises();
        expect(duoUserFeedbackMutationHandlerMock).toHaveBeenCalledWith({
          input: {
            aiMessageId: feedbackData.message.id,
            trackingEvent: {
              category: TANUKI_BOT_TRACKING_EVENT_NAME,
              action: 'click_button',
              label: 'response_feedback',
              property: 'useful,not_relevant',
              extra: {
                improveWhat: 'more examples',
                didWhat: 'provided clarity',
                prompt_location: 'after_content',
              },
            },
          },
        });
      });

      it('updates Vuex store correctly when message is passed', async () => {
        createComponent();
        findDuoChat().vm.$emit('track-feedback', feedbackData);

        await waitForPromises();
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.any(Object),
          expect.objectContaining({
            requestId: feedbackData.message.requestId,
            role: feedbackData.message.role,
            content: feedbackData.message.content,
            extras: { ...feedbackData.message.extras, hasFeedback: true },
          }),
        );
      });
    });
  });

  describe('Error conditions', () => {
    const errorText = 'Fancy foo';

    it('does call addDuoChatMessage', async () => {
      queryHandlerMock.mockImplementationOnce(() => Promise.reject(new Error(errorText)));
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
        expect.anything(),
        expect.objectContaining({
          errors: [`Error: ${errorText}`],
        }),
      );
    });

    describe('when mutation fails', () => {
      it('throws an error, but still calls addDuoChatMessage', async () => {
        chatMutationHandlerMock.mockRejectedValue(new Error(errorText));
        duoChatGlobalState.isShown = true;
        createComponent();
        await waitForPromises();
        findDuoChat().vm.$emit('send-chat-prompt', MOCK_USER_MESSAGE.content);
        await waitForPromises();

        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            content: MOCK_USER_MESSAGE.content,
          }),
        );
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          expect.objectContaining({
            errors: [`Error: ${errorText}`],
          }),
        );
      });
    });
  });

  describe('Subscription Component', () => {
    afterEach(() => {
      duoChatGlobalState.isShown = false;
      jest.clearAllMocks();
    });

    it('renders AiResponseSubscription component with correct props when isShown is true', async () => {
      duoChatGlobalState.isShown = true;
      createComponent();
      await waitForPromises();

      expect(findSubscriptions().exists()).toBe(true);
      expect(findSubscriptions().props('userId')).toBe(MOCK_USER_ID);
      expect(findSubscriptions().props('clientSubscriptionId')).toBe(UUIDMOCK);
      expect(findSubscriptions().props('cancelledRequestIds')).toHaveLength(0);
    });

    it('does not render AiResponseSubscription component when isShown is false', async () => {
      duoChatGlobalState.isShown = false;
      createComponent();
      await waitForPromises();

      expect(findSubscriptions().exists()).toBe(false);
    });

    it('calls addDuoChatMessage when @message is fired', () => {
      duoChatGlobalState.isShown = true;
      createComponent();
      const mockMessage = {
        content: 'test message content',
        role: 'user',
      };

      findSubscriptions().vm.$emit('message', mockMessage);
      expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), mockMessage);
    });

    describe('Subscription Component', () => {
      beforeEach(() => {
        duoChatGlobalState.isShown = true;
        createComponent();
        mockTracking(undefined, wrapper.element, jest.spyOn);
        performance.mark = jest.fn();
      });

      it('stops adding new messages when more chunks with the same request ID come in after the full message has already been received', () => {
        const requestId = '123';
        const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
        const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, requestId);
        const successResponse = GENERATE_MOCK_TANUKI_RES('', requestId);

        // message chunk streaming in
        findSubscriptions().vm.$emit('message-stream', firstChunk);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), firstChunk);

        // full message being sent
        findSubscriptions().vm.$emit('message', successResponse);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          successResponse,
        );
        // another chunk with the same request ID
        findSubscriptions().vm.$emit('message-stream', secondChunk);
        // addDuoChatMessage should not be called since the full message was already sent
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledTimes(2);
      });

      it('continues to invoke addDuoChatMessage when a new message chunk arrives with a distinct request ID, even after a complete message has been received', () => {
        const firstRequestId = '123';
        const secondRequestId = '124';
        const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, firstRequestId);
        const secondChunk = MOCK_CHUNK_MESSAGE('second chunk', 2, firstRequestId);
        const successResponse = GENERATE_MOCK_TANUKI_RES('', secondRequestId);

        // message chunk streaming in
        findSubscriptions().vm.$emit('message-stream', firstChunk);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(expect.anything(), firstChunk);

        // full message being sent
        findSubscriptions().vm.$emit('message', successResponse);
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          successResponse,
        );
        // another chunk with a new request ID
        findSubscriptions().vm.$emit('message-stream', secondChunk);
        // addDuoChatMessage should be called since the second chunk has a new requestId
        expect(actionSpies.addDuoChatMessage).toHaveBeenCalledWith(
          expect.anything(),
          successResponse,
        );
      });

      it('clears the commands when streaming is done', () => {
        const requestId = '123';
        const firstChunk = MOCK_CHUNK_MESSAGE('first chunk', 1, requestId);
        const successResponse = GENERATE_MOCK_TANUKI_RES('', requestId);

        expect(duoChatGlobalState.commands).toHaveLength(0);
        sendDuoChatCommand({ question: '/troubleshoot', resourceId: '1' });
        expect(duoChatGlobalState.commands).toHaveLength(1);

        createComponent();

        // message chunk streaming in
        findSubscriptions().vm.$emit('message-stream', firstChunk);
        // No changes to commands
        expect(duoChatGlobalState.commands).toHaveLength(1);
        // full message being sent
        findSubscriptions().vm.$emit('message', successResponse);
        // commands have been cleared out
        expect(duoChatGlobalState.commands).toHaveLength(0);
      });
    });
  });

  describe('Resizable Dimensions', () => {
    beforeEach(() => {
      duoChatGlobalState.isShown = true;
      createComponent();
    });

    it('initializes `left` as undefined in dimensions before mounted lifecycle alters it', () => {
      const setDimensionsSpy = jest
        .spyOn(TanukiBotChatApp.methods, 'setDimensions')
        .mockImplementation(() => {});
      createComponent();
      expect(wrapper.vm.dimensions.left).toBe(null);
      setDimensionsSpy.mockRestore();
    });

    it('initializes dimensions correctly on mount', () => {
      createComponent();
      expect(wrapper.vm.width).toBe(400);
      expect(wrapper.vm.height).toBe(window.innerHeight);
      expect(wrapper.vm.maxWidth).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.maxHeight).toBe(window.innerHeight);
    });

    it('updates dimensions correctly when `chat-resize` event is emitted', async () => {
      const newWidth = 600;
      const newHeight = 500;
      const chat = findDuoChat();
      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(newWidth);
      expect(wrapper.vm.height).toBe(newHeight);
    });

    it('ensures dimensions do not exceed maxWidth or maxHeight', async () => {
      const newWidth = window.innerWidth + 100;
      const newHeight = window.innerHeight + 100;
      const chat = findDuoChat();

      chat.vm.$emit('chat-resize', { width: newWidth, height: newHeight });
      await nextTick();

      expect(wrapper.vm.width).toBe(window.innerWidth - WIDTH_OFFSET);
      expect(wrapper.vm.height).toBe(window.innerHeight);
    });

    it('updates dimensions when the window is resized', async () => {
      createComponent();
      window.innerWidth = 1200;
      window.innerHeight = 800;

      window.dispatchEvent(new Event('resize'));
      await nextTick();

      expect(wrapper.vm.maxWidth).toBe(1200 - WIDTH_OFFSET);
      expect(wrapper.vm.maxHeight).toBe(800);
    });

    it('renders DuoChat with shouldRenderResizable=false when duoChatDynamicDimension flag is false', () => {
      createComponent({ glFeatures: { duoChatDynamicDimension: false } });
      const duoChat = findDuoChat();
      expect(duoChat.exists()).toBe(true);
      expect(duoChat.props('shouldRenderResizable')).toBe(false);
    });

    it('renders DuoChat with shouldRenderResizable=true when duoChatDynamicDimension flag is true', () => {
      createComponent({ glFeatures: { duoChatDynamicDimension: true } });
      const duoChat = findDuoChat();
      expect(duoChat.exists()).toBe(true);
      expect(duoChat.props('shouldRenderResizable')).toBe(true);
    });
  });
});
