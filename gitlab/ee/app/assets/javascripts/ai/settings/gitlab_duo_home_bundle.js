import Vue from 'vue';
import { parseBoolean } from '~/lib/utils/common_utils';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';
import apolloProvider from 'ee/usage_quotas/shared/provider';
import { parseProvideData } from 'ee/usage_quotas/code_suggestions/tab_metadata';

export function initGitLabDuoHome() {
  const el = document.getElementById('js-gitlab-duo-home');

  if (!el) return false;

  return new Vue({
    el,
    name: 'GitlabDuoHome',
    apolloProvider,
    provide() {
      return {
        ...parseProvideData(el),
        duoSeatUtilizationPath: el.dataset.duoSeatUtilizationPath,
        duoConfigurationPath: el.dataset.duoConfigurationPath,
        duoAvailability: el.dataset.duoAvailability,
        experimentFeaturesEnabled: parseBoolean(el.dataset.experimentFeaturesEnabled),
        areExperimentSettingsAllowed: parseBoolean(el.dataset.areExperimentSettingsAllowed),
      };
    },
    render(createElement) {
      return createElement(GitlabDuoHome);
    },
  });
}
