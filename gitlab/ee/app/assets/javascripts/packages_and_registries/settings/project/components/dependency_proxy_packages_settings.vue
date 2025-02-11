<script>
import { GlAlert, GlCard, GlSkeletonLoader } from '@gitlab/ui';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import getDependencyProxyPackagesSettings from 'ee_component/packages_and_registries/settings/project/graphql/queries/get_dependency_proxy_packages_settings.query.graphql';
import DependencyProxyPackagesSettingsForm from 'ee_component/packages_and_registries/settings/project/components/dependency_proxy_packages_settings_form.vue';

export default {
  name: 'DependencyProxyPackagesSettings',
  components: {
    DependencyProxyPackagesSettingsForm,
    GlAlert,
    GlCard,
    GlSkeletonLoader,
  },
  inject: {
    projectPath: {
      default: '',
    },
  },
  apollo: {
    dependencyProxyPackagesSettings: {
      query: getDependencyProxyPackagesSettings,
      context: {
        batchKey: 'PackageRegistryProjectSettings',
      },
      variables() {
        return {
          projectPath: this.projectPath,
        };
      },
      update: (data) => data.project?.dependencyProxyPackagesSetting || {},
      error(e) {
        this.fetchSettingsError = e;
        Sentry.captureException(e);
      },
    },
  },
  data() {
    return {
      dependencyProxyPackagesSettings: {},
      fetchSettingsError: false,
    };
  },
  computed: {
    isLoading() {
      return this.$apollo.queries.dependencyProxyPackagesSettings.loading;
    },
  },
};
</script>

<template>
  <gl-card data-testid="dependency-proxy-settings">
    <template #header>
      <h2 class="gl-m-0 gl-inline-flex gl-items-center gl-text-base gl-font-bold gl-leading-normal">
        {{ s__('DependencyProxy|Dependency Proxy') }}
      </h2>
    </template>
    <template #default>
      <p class="gl-text-subtle" data-testid="description">
        {{
          s__(
            'DependencyProxy|Enable the Dependency Proxy for packages, and configure connection settings for external registries.',
          )
        }}
      </p>

      <gl-alert v-if="fetchSettingsError" variant="warning" :dismissible="false">
        {{
          s__('DependencyProxy|Something went wrong while fetching the dependency proxy settings.')
        }}
      </gl-alert>

      <gl-skeleton-loader v-else-if="isLoading" />
      <dependency-proxy-packages-settings-form v-else :data="dependencyProxyPackagesSettings" />
    </template>
  </gl-card>
</template>
