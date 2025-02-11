<script>
import { GlAlert, GlButton, GlLoadingIcon } from '@gitlab/ui';
import { __, s__, sprintf } from '~/locale';
import { createAlert } from '~/alert';
import { localeDateFormat } from '~/lib/utils/datetime_utility';
import { convertEnvironmentScope } from '~/ci/common/private/ci_environments_dropdown';
import {
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  SECRET_STATUS,
  SCOPED_LABEL_COLOR,
} from '../../constants';
import getSecretDetailsQuery from '../../graphql/queries/get_secret_details.query.graphql';
import SecretDetails from './secret_details.vue';

export default {
  name: 'SecretDetailsWrapper',
  components: {
    GlAlert,
    GlButton,
    GlLoadingIcon,
    SecretDetails,
  },
  props: {
    fullPath: {
      type: String,
      required: false,
      default: null,
    },
    routeName: {
      type: String,
      required: true,
    },
    secretName: {
      type: String,
      required: true,
    },
  },
  apollo: {
    secret: {
      skip() {
        return !this.secretName;
      },
      query: getSecretDetailsQuery,
      variables() {
        return {
          fullPath: this.fullPath,
          name: this.secretName,
        };
      },
      update(data) {
        return data.projectSecret || null;
      },
      error() {
        createAlert({ message: this.$options.i18n.queryError });
      },
    },
  },
  data() {
    return {
      secret: null,
    };
  },
  computed: {
    createdAtText() {
      const date = localeDateFormat.asDate.format(new Date(this.secret.createdAt));
      return sprintf(__('Created on %{date}'), { date });
    },
    environmentLabelText() {
      const { environment } = this.secret;
      const environmentText = convertEnvironmentScope(environment).toLowerCase();
      return `${__('env')}::${environmentText}`;
    },
    isSecretLoading() {
      return this.$apollo.queries.secret.loading;
    },
  },
  methods: {
    goToEdit() {
      this.$router.push({ name: EDIT_ROUTE_NAME, params: { secretName: this.secretName } });
    },
    goTo(name) {
      if (this.routeName !== name) {
        this.$router.push({ name });
      }
    },
  },
  i18n: {
    queryError: s__('Secrets|Failed to load secret. Please try again later.'),
  },
  DETAILS_ROUTE_NAME,
  EDIT_ROUTE_NAME,
  SCOPED_LABEL_COLOR,
  SECRET_STATUS,
};
</script>
<template>
  <div>
    <gl-loading-icon v-if="isSecretLoading" size="lg" class="gl-mt-6" />
    <gl-alert v-else-if="!secret" variant="danger" :dismissible="false" class="gl-mt-3">
      {{ $options.i18n.queryError }}
    </gl-alert>
    <div v-else>
      <div class="gl-flex gl-items-center gl-justify-between">
        <h1 class="page-title gl-text-size-h-display">{{ secret.name }}</h1>
        <div>
          <gl-button
            icon="pencil"
            :aria-label="__('Edit')"
            data-testid="secret-edit-button"
            @click="goToEdit"
          />
          <gl-button
            :aria-label="__('Revoke')"
            category="secondary"
            variant="danger"
            data-testid="secret-revoke-button"
          >
            {{ __('Revoke') }}
          </gl-button>
          <gl-button :aria-label="__('Delete')" variant="danger" data-testid="secret-delete-button">
            {{ __('Delete') }}
          </gl-button>
        </div>
      </div>
      <secret-details :full-path="fullPath" :secret="secret" />
    </div>
  </div>
</template>
