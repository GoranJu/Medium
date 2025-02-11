import initEETrialBanner from 'ee/ee_trial_banner';
import initNamespaceUserCapReachedAlert from 'ee/namespace_user_cap_reached_alert';
import { initTanukiBotChatDrawer } from 'ee/ai/tanuki_bot';
import { initSamlReloadModal } from 'ee/saml_sso/index';

// EE specific calls
initEETrialBanner();
initNamespaceUserCapReachedAlert();

initTanukiBotChatDrawer();
initSamlReloadModal();
