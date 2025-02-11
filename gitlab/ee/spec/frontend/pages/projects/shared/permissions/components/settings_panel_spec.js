import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import SecretManagerSettings from 'ee_component/pages/projects/shared/permissions/components/secret_manager_settings.vue';
import settingsPanel from '~/pages/projects/shared/permissions/components/settings_panel.vue';

const defaultProps = {
  currentSettings: {
    showDefaultAwardEmojis: true,
  },
  canAddCatalogResource: false,
  confirmationPhrase: 'my-fake-project',
  membersPagePath: '/my-fake-project/-/project_members',
};

describe('Settings Panel', () => {
  let wrapper;

  const mountComponent = ({ ...customProps } = {}) => {
    const propsData = {
      ...defaultProps,
      ...customProps,
      currentSettings: { ...defaultProps.currentSettings },
    };

    return shallowMountExtended(settingsPanel, {
      propsData,
      provide: {
        cascadingSettingsData: {},
      },
    });
  };

  const findSecretManagerSettings = () => wrapper.findComponent(SecretManagerSettings);

  describe('Secret Manager Settings', () => {
    it('should show the Secret Manager settings if user has permission', () => {
      wrapper = mountComponent({ canManageSecretManager: true });

      expect(findSecretManagerSettings().exists()).toBe(true);
    });

    it('should not show the Secret Manager settings if user does not have permission', () => {
      wrapper = mountComponent({ canManageSecretManager: false });

      expect(findSecretManagerSettings().exists()).toBe(false);
    });
  });
});
