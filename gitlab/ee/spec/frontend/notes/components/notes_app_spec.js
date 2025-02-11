import { shallowMount } from '@vue/test-utils';
import { v4 as uuidv4 } from 'uuid';
import waitForPromises from 'helpers/wait_for_promises';
import NotesApp from '~/notes/components/notes_app.vue';
import AiSummary from 'ee_component/notes/components/ai_summary.vue';
import createStore from '~/notes/stores';
// TODO: use generated fixture (https://gitlab.com/gitlab-org/gitlab-foss/issues/62491)
import * as mockData from '../../../../../spec/frontend/notes/mock_data';

jest.mock('~/behaviors/markdown/render_gfm');
jest.mock('uuid');

const propsData = {
  noteableData: mockData.noteableDataMock,
  notesData: mockData.notesDataMock,
  notesFilters: mockData.notesFilters,
};

describe('note_app', () => {
  let mountComponent;
  let wrapper;
  let store;

  beforeEach(() => {
    store = createStore();

    mountComponent = () => {
      return shallowMount(NotesApp, {
        store,
        propsData,
        provide: {
          resourceGlobalId: 'gid://Gitlab/Issue/1',
        },
        data() {
          return {
            aiLoading: false,
          };
        },
      });
    };
  });

  describe('provide', () => {
    beforeEach(async () => {
      uuidv4.mockImplementation(() => 'uuid');

      wrapper = await mountComponent();
      await waitForPromises();
    });

    it('provides summarizeClientSubscriptionId', () => {
      expect(wrapper.findComponent(AiSummary).vm.summarizeClientSubscriptionId).toBe('uuid');
    });
  });
});
