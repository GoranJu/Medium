import { initTrialCreateLeadForm } from 'ee/trials/init_create_lead_form';
import { trackSaasTrialSubmit } from 'ee/google_tag_manager';
import { initNamespaceSelector } from 'ee/trials/init_namespace_selector';

trackSaasTrialSubmit('.js-saas-trial-group', 'saasTrialGroup');
initTrialCreateLeadForm('saasTrialSubmit');
initNamespaceSelector();
