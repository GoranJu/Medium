import { shallowMount } from '@vue/test-utils';
import LockFileButton from 'ee_component/repository/components/lock_file_button.vue';
import BlobButtonGroup from '~/repository/components/blob_button_group.vue';

const DEFAULT_PROPS = {
  name: 'some name',
  path: 'some/path',
  canPushCode: true,
  canPushToBranch: true,
  replacePath: 'some/replace/path',
  deletePath: 'some/delete/path',
  emptyRepo: false,
  projectPath: 'some/project/path',
  isLocked: false,
  canLock: true,
  showForkSuggestion: false,
  handleFormSubmit: jest.fn(),
};

const DEFAULT_INJECT = {
  glFeatures: { fileLocks: true },
  targetBranch: 'master',
  originalBranch: 'master',
};

describe('EE BlobButtonGroup component', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(BlobButtonGroup, {
      propsData: {
        ...DEFAULT_PROPS,
        ...props,
      },
      provide: {
        ...DEFAULT_INJECT,
      },
      stubs: {
        LockFileButton,
      },
    });
  };

  const findLockFileButton = () => wrapper.findComponent(LockFileButton);

  beforeEach(() => {
    createComponent();
  });

  it('renders component', () => {
    const { name, path } = DEFAULT_PROPS;

    expect(wrapper.props()).toMatchObject({
      name,
      path,
    });
  });

  it('renders the lock button', () => {
    expect(findLockFileButton().exists()).toBe(true);

    expect(findLockFileButton().props()).toMatchObject({
      canLock: true,
      isLocked: false,
      name: 'some name',
      path: 'some/path',
      projectPath: 'some/project/path',
    });
  });
});
