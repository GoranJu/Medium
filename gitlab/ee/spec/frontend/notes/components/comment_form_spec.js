import MockAdapter from 'axios-mock-adapter';
import Vue, { nextTick } from 'vue';
// eslint-disable-next-line no-restricted-imports
import Vuex from 'vuex';
import { mountExtended, shallowMountExtended } from 'helpers/vue_test_utils_helper';
import { useLocalStorageSpy } from 'helpers/local_storage_helper';
import CommentTemperature from 'ee_component/ai/components/comment_temperature.vue';
import axios from '~/lib/utils/axios_utils';
import eventHub from '~/notes/event_hub';
import MarkdownEditor from '~/vue_shared/components/markdown/markdown_editor.vue';
import CommentForm from '~/notes/components/comment_form.vue';
import notesModule from '~/notes/stores/modules';
import { detectAndConfirmSensitiveTokens } from '~/lib/utils/secret_detection';
import {
  notesDataMock,
  userDataMock,
  noteableDataMock,
} from '../../../../../spec/frontend/notes/mock_data';

jest.mock('autosize');
jest.mock('~/super_sidebar/user_counts_fetch');
jest.mock('~/alert');
jest.mock('~/lib/utils/secret_detection', () => {
  return {
    detectAndConfirmSensitiveTokens: jest.fn(() => Promise.resolve(true)),
  };
});

Vue.use(Vuex);

describe('issue_comment_form component', () => {
  useLocalStorageSpy();

  let wrapper;
  let axiosMock;

  const findMarkdownEditor = () => wrapper.findComponent(MarkdownEditor);
  const findMarkdownEditorTextarea = () => findMarkdownEditor().find('textarea');
  const findCommentTypeDropdown = () => wrapper.findByTestId('comment-button');
  const findCommentButton = () => findCommentTypeDropdown().find('button');
  const findStartReviewButton = () => wrapper.findByTestId('start-review-button');
  const findCommentTemperature = () => wrapper.findComponent(CommentTemperature);

  const createStore = ({ actions = { saveNote: jest.fn() }, state = {}, getters = {} } = {}) => {
    const baseModule = notesModule();

    return new Vuex.Store({
      ...baseModule,
      actions: {
        ...baseModule.actions,
        ...actions,
      },
      state: {
        ...baseModule.state,
        ...state,
      },
      getters: {
        ...baseModule.getters,
        ...getters,
      },
    });
  };

  const mountComponent = ({
    initialData = {},
    noteableType = 'Issue',
    noteableData = noteableDataMock,
    notesData = notesDataMock,
    userData = userDataMock,
    features = {},
    abilities = {},
    mountFunction = shallowMountExtended,
    store = createStore(),
    stubs = {},
  } = {}) => {
    store.dispatch('setNoteableData', noteableData);
    store.dispatch('setNotesData', notesData);
    store.dispatch('setUserData', userData);

    wrapper = mountFunction(CommentForm, {
      propsData: {
        noteableType,
      },
      data() {
        return {
          ...initialData,
        };
      },
      store,
      provide: {
        glFeatures: features,
        glAbilities: abilities,
      },
      stubs,
    });
  };

  beforeEach(() => {
    axiosMock = new MockAdapter(axios);
    detectAndConfirmSensitiveTokens.mockReturnValue(true);
  });

  afterEach(() => {
    axiosMock.restore();
    detectAndConfirmSensitiveTokens.mockReset();
  });

  describe('comment temperature', () => {
    const note = 'very bad note';

    describe('without the ability to measure it', () => {
      beforeEach(() => {
        const store = createStore();
        mountComponent({
          mountFunction: shallowMountExtended,
          initialData: { note },
          store,
        });
      });

      it('does not render the comment temperature component', () => {
        expect(findCommentTemperature().exists()).toBe(false);
      });
    });

    describe('with ability to measure it', () => {
      let store;
      let bootstrapFn;

      const saveMock = jest.fn().mockReturnValue();
      const measureCommentTemperatureMock = jest.fn();
      beforeEach(() => {
        store = createStore({
          actions: {
            saveNote: saveMock,
          },
        });
        bootstrapFn = (initNote = note) => {
          mountComponent({
            mountFunction: mountExtended,
            initialData: { note: initNote },
            abilities: {
              measureCommentTemperature: true,
            },
            store,
            stubs: {
              CommentTemperature,
            },
          });
          wrapper.findComponent(CommentTemperature).vm.measureCommentTemperature =
            measureCommentTemperatureMock;
        };
        bootstrapFn();
      });

      it('does not measure temperature on the slash commands', async () => {
        bootstrapFn('/close');
        findCommentButton().trigger('click');
        await nextTick();
        expect(measureCommentTemperatureMock).not.toHaveBeenCalled();
        expect(saveMock).toHaveBeenCalled();
      });

      it('renders the comment temperature component', () => {
        expect(findCommentTemperature().exists()).toBe(true);
      });

      it('should measure comment temperature and not send', async () => {
        findCommentButton().trigger('click');
        await nextTick();
        expect(measureCommentTemperatureMock).toHaveBeenCalled();
        expect(saveMock).not.toHaveBeenCalledWith();
      });

      it('should not make textarea disabled while measuring the temperature', async () => {
        findCommentButton().trigger('click');
        await nextTick();
        expect(findMarkdownEditor().find('textarea').attributes('disabled')).toBeUndefined();
      });

      it('should not clear the text input while measuring the temperature', async () => {
        findCommentButton().trigger('click');
        await nextTick();
        expect(findMarkdownEditorTextarea().element.value).toBe('very bad note');
      });

      describe('when the Comment Temperature component asks to save', () => {
        it('does not measure temperature', async () => {
          findCommentButton().trigger('click');
          await nextTick();
          expect(measureCommentTemperatureMock).toHaveBeenCalled();
          expect(saveMock).not.toHaveBeenCalledWith();

          findCommentTemperature().vm.$emit('save');
          await nextTick();
          expect(saveMock).toHaveBeenCalled();
          expect(measureCommentTemperatureMock).toHaveBeenCalledTimes(1);
        });

        it('does save the draft when `start-review-button` is clicked in an MR', async () => {
          mountComponent({
            mountFunction: mountExtended,
            noteableType: 'MergeRequest',
            initialData: { note },
            abilities: {
              measureCommentTemperature: true,
            },
            store,
            stubs: {
              CommentTemperature,
            },
          });
          wrapper.findComponent(CommentTemperature).vm.measureCommentTemperature =
            measureCommentTemperatureMock;

          jest.spyOn(eventHub, '$emit');
          findStartReviewButton().trigger('click');
          await nextTick();
          expect(measureCommentTemperatureMock).toHaveBeenCalled();
          expect(saveMock).not.toHaveBeenCalledWith();
          expect(eventHub.$emit).not.toHaveBeenCalled();

          findCommentTemperature().vm.$emit('save');
          await nextTick();
          expect(saveMock).toHaveBeenCalled();
          expect(eventHub.$emit).toHaveBeenCalledWith('noteFormAddToReview', {
            name: 'noteFormAddToReview',
          });
        });
      });
    });
  });
});
