<script>
import {
  GlAlert,
  GlBadge,
  GlButton,
  GlLabel,
  GlLoadingIcon,
  GlSprintf,
  GlTableLite,
  GlPagination,
} from '@gitlab/ui';
import { updateHistory, getParameterByName, setUrlParams } from '~/lib/utils/url_utility';
import { __, s__ } from '~/locale';
import { createAlert } from '~/alert';
import CrudComponent from '~/vue_shared/components/crud_component.vue';
import TimeAgo from '~/vue_shared/components/time_ago_tooltip.vue';
import UserDate from '~/vue_shared/components/user_date.vue';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import getSecretsQuery from '../../graphql/queries/client/get_secrets.query.graphql';
import getSecretManagerStatusQuery from '../../graphql/queries/get_secret_manager_status.query.graphql';
import {
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  INITIAL_PAGE,
  NEW_ROUTE_NAME,
  PAGE_SIZE,
  POLL_INTERVAL,
  SCOPED_LABEL_COLOR,
  SECRET_MANAGER_STATUS_ACTIVE,
  SECRET_MANAGER_STATUS_INACTIVE,
  SECRET_MANAGER_STATUS_PROVISIONING,
  SECRET_STATUS,
  UNSCOPED_LABEL_COLOR,
} from '../../constants';
import SecretActionsCell from './secret_actions_cell.vue';

export default {
  name: 'SecretsTable',
  components: {
    CrudComponent,
    GlAlert,
    GlBadge,
    GlButton,
    GlLabel,
    GlLoadingIcon,
    GlPagination,
    GlSprintf,
    GlTableLite,
    TimeAgo,
    UserDate,
    SecretActionsCell,
  },
  props: {
    isGroup: {
      type: Boolean,
      required: true,
    },
    fullPath: {
      type: String,
      required: true,
    },
  },
  data() {
    return {
      secretManagerStatus: null,
      secrets: null,
      page: INITIAL_PAGE,
    };
  },
  apollo: {
    secretManagerStatus: {
      query: getSecretManagerStatusQuery,
      variables() {
        return {
          projectPath: this.fullPath,
        };
      },
      update({ projectSecretsManager }) {
        const newStatus = projectSecretsManager?.status || SECRET_MANAGER_STATUS_INACTIVE;

        if (newStatus !== SECRET_MANAGER_STATUS_PROVISIONING) {
          this.$apollo.queries.secretManagerStatus.stopPolling();
        }

        if (newStatus === SECRET_MANAGER_STATUS_ACTIVE) {
          this.$apollo.queries.secrets.refetch();
        }

        return newStatus;
      },
      error() {
        createAlert({
          message: s__(
            'Secrets|An error occurred while fetching the Secret manager status. Please try again.',
          ),
        });
      },
      pollInterval: POLL_INTERVAL,
    },
    secrets: {
      query: getSecretsQuery,
      skip() {
        return (
          !this.secretManagerStatus || !this.secretManagerStatus === SECRET_MANAGER_STATUS_ACTIVE
        );
      },
      variables() {
        return this.queryVariables;
      },
      update(data) {
        if (this.isGroup) {
          return data.group?.secrets;
        }
        return data.project?.secrets;
      },
      error() {
        createAlert({ message: __('An error occurred while fetching secrets, please try again.') });
      },
    },
  },
  computed: {
    isProvisioning() {
      return this.secretManagerStatus === SECRET_MANAGER_STATUS_PROVISIONING;
    },
    onSecretsPage() {
      return window.location.pathname.includes('/-/secrets');
    },
    queryVariables() {
      return {
        fullPath: this.fullPath,
        isGroup: this.isGroup,
        offset: (this.page - 1) * PAGE_SIZE,
        limit: PAGE_SIZE,
      };
    },
    secretsCount() {
      return this.secrets?.count || 0;
    },
    secretsNodes() {
      return this.secrets?.nodes || [];
    },
    showPagination() {
      return this.secretsCount > PAGE_SIZE;
    },
  },
  created() {
    this.updateQueryParamsFromUrl();

    window.addEventListener('popstate', this.updateQueryParamsFromUrl);
  },
  destroyed() {
    window.removeEventListener('popstate', this.updateQueryParamsFromUrl);
  },
  methods: {
    getDetailsRoute: (secretName) => ({ name: DETAILS_ROUTE_NAME, params: { secretName } }),
    getEditRoute: (id) => ({ name: EDIT_ROUTE_NAME, params: { id } }),
    isScopedLabel(label) {
      return label.includes('::');
    },
    getLabelBackgroundColor(label) {
      return this.isScopedLabel(label) ? SCOPED_LABEL_COLOR : UNSCOPED_LABEL_COLOR;
    },
    environmentLabelText(environment) {
      const environmentText = convertEnvironmentScope(environment);
      return `${__('env')}::${environmentText}`;
    },
    updateQueryParamsFromUrl() {
      this.page = Number(getParameterByName('page')) || INITIAL_PAGE;
    },
    handlePageChange(page) {
      this.page = page;
      if (this.onSecretsPage) {
        updateHistory({
          url: setUrlParams({ page }),
        });
      }
    },
  },
  fields: [
    {
      key: 'name',
      label: s__('Secrets|Name'),
    },
    {
      key: 'lastAccessed',
      label: s__('Secrets|Last used'),
    },
    {
      key: 'expiration',
      label: s__('Secrets|Expires'),
    },
    {
      key: 'createdAt',
      label: s__('Secrets|Created'),
    },
    {
      key: 'status',
      label: s__('Secrets|Status'),
    },
    {
      key: 'actions',
      label: '',
      tdClass: 'gl-text-right !gl-p-3',
    },
  ],
  NEW_ROUTE_NAME,
  PAGE_SIZE,
  SCOPED_LABEL_COLOR,
  SECRET_STATUS,
};
</script>
<template>
  <div>
    <h1 v-if="onSecretsPage" class="page-title gl-text-size-h-display">
      {{ s__('Secrets|Secrets') }}
    </h1>
    <p>
      <gl-sprintf
        :message="
          s__(
            'Secrets|Secrets can be items like API tokens, database credentials, or private keys. Unlike CI/CD variables, secrets must be explicitly requested by a job.',
          )
        "
      />
    </p>
    <gl-loading-icon v-if="!secretManagerStatus" />
    <gl-alert
      v-else-if="isProvisioning"
      class="gl-mb-3"
      :title="s__('Secrets|Provisioning in progress')"
      :dismissible="false"
    >
      {{
        s__(
          'Secrets|Please wait while the Secrets manager is provisioned. It is safe to refresh this page.',
        )
      }}
    </gl-alert>
    <crud-component v-else :title="s__('Secrets|Stored secrets')" icon="lock" :count="secretsCount">
      <template #actions>
        <gl-button size="small" :to="$options.NEW_ROUTE_NAME" data-testid="new-secret-button">
          {{ s__('Secrets|New secret') }}
        </gl-button>
      </template>

      <gl-table-lite :fields="$options.fields" :items="secretsNodes" stacked="md" class="gl-mb-0">
        <template #cell(name)="{ item: { name, labels, environment } }">
          <router-link
            data-testid="secret-details-link"
            :to="getDetailsRoute(name)"
            class="gl-block"
          >
            {{ name }}
          </router-link>
          <gl-label
            :title="environmentLabelText(environment)"
            :background-color="$options.SCOPED_LABEL_COLOR"
            scoped
          />
          <gl-label
            v-for="label in labels"
            :key="label"
            :title="label"
            :background-color="getLabelBackgroundColor(label)"
            :scoped="isScopedLabel(label)"
            class="gl-mr-3 gl-mt-3"
          />
        </template>
        <template #cell(lastAccessed)="{ item: { lastAccessed } }">
          <time-ago :time="lastAccessed" data-testid="secret-last-accessed" />
        </template>
        <template #cell(expiration)="{ item: { expiration } }">
          <user-date :date="expiration" data-testid="secret-expiration" />
        </template>
        <template #cell(createdAt)="{ item: { createdAt } }">
          <user-date :date="createdAt" data-testid="secret-created-at" />
        </template>
        <template #cell(status)="{ item: { status } }">
          <gl-badge
            :icon="$options.SECRET_STATUS[status].icon"
            :variant="$options.SECRET_STATUS[status].variant"
          >
            {{ $options.SECRET_STATUS[status].text }}
          </gl-badge>
        </template>
        <template #cell(actions)="{ item: { id } }">
          <secret-actions-cell :details-route="getEditRoute(id)" />
        </template>
      </gl-table-lite>

      <template v-if="showPagination" #pagination>
        <gl-pagination
          :value="page"
          :per-page="$options.PAGE_SIZE"
          :total-items="secretsCount"
          align="center"
          @input="handlePageChange"
        />
      </template>
    </crud-component>
  </div>
</template>
