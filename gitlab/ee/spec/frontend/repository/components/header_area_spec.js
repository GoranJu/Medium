import { RouterLinkStub } from '@vue/test-utils';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import HeaderArea from '~/repository/components/header_area.vue';
import LockDirectoryButton from 'ee_component/repository/components/lock_directory_button.vue';
import CodeDropdown from '~/vue_shared/components/code_dropdown/code_dropdown.vue';
import CompactCodeDropdown from '~/repository/components/code_dropdown/compact_code_dropdown.vue';
import CloneCodeDropdown from '~/vue_shared/components/code_dropdown/clone_code_dropdown.vue';
import { headerAppInjected } from 'ee_else_ce_jest/repository/mock_data';

const defaultMockRoute = {
  params: {
    path: '/directory',
  },
  meta: {
    refType: '',
  },
  query: {
    ref_type: '',
  },
};

describe('HeaderArea', () => {
  let wrapper;

  const findLockDirectoryButton = () => wrapper.findComponent(LockDirectoryButton);
  const findCodeDropdown = () => wrapper.findComponent(CodeDropdown);
  const findCompactCodeDropdown = () => wrapper.findComponent(CompactCodeDropdown);
  const findCloneCodeDropdown = () => wrapper.findComponent(CloneCodeDropdown);

  const createComponent = (props = {}, params = { path: '/directory' }, provided = {}) => {
    return shallowMountExtended(HeaderArea, {
      provide: {
        ...headerAppInjected,
        ...provided,
      },
      propsData: {
        projectPath: 'test/project',
        historyLink: '/history',
        refType: 'branch',
        projectId: '123',
        refSelectorValue: 'refs/heads/main',
        ...props,
      },
      stubs: {
        RouterLink: RouterLinkStub,
      },
      mocks: {
        $route: {
          ...defaultMockRoute,
          params,
        },
      },
    });
  };

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('when rendered for tree view', () => {
    describe('Lock button', () => {
      it('renders Lock directory button for directories inside the project', () => {
        expect(findLockDirectoryButton().exists()).toBe(true);
      });

      it('does not render Lock directory button for root directory', () => {
        wrapper = createComponent({}, 'treePathDecoded', { params: '/' });
        expect(findLockDirectoryButton().exists()).toBe(false);
      });
    });
    describe('CodeDropdown', () => {
      describe('when `directory_code_dropdown_updates` flag is false', () => {
        it('renders CodeDropdown component with correct props for desktop layout', () => {
          expect(findCodeDropdown().exists()).toBe(true);
          expect(findCodeDropdown().props('kerberosUrl')).toBe(headerAppInjected.kerberosUrl);
        });
      });

      describe('when `directory_code_dropdown_updates` flag is true', () => {
        it('renders CommpactCodeDropdown component with correct props for desktop layout', () => {
          wrapper = createComponent({}, '', {
            glFeatures: {
              directoryCodeDropdownUpdates: true,
            },
          });
          expect(findCompactCodeDropdown().exists()).toBe(true);
          expect(findCompactCodeDropdown().props('kerberosUrl')).toBe(
            headerAppInjected.kerberosUrl,
          );
        });
      });
    });

    describe('SourceCodeDownloadDropdown', () => {
      it('renders CloneCodeDropdown component with correct props for mobile layout', () => {
        expect(findCloneCodeDropdown().exists()).toBe(true);
        expect(findCloneCodeDropdown().props('kerberosUrl')).toBe(headerAppInjected.kerberosUrl);
      });
    });
  });
});
