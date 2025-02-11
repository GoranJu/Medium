<script>
import { GlSprintf, GlLink, GlToggle } from '@gitlab/ui';
import { s__ } from '~/locale';
import { helpPagePath } from '~/helpers/help_page_helper';
import { isNumeric } from '~/lib/utils/number_utils';
import { getIdFromGraphQLId } from '~/graphql_shared/utils';
import UserSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/user_select.vue';

export default {
  SKIP_CI_PATH: helpPagePath('ci/pipelines/_index.md', { anchor: 'skip-a-pipeline' }),
  i18n: {
    skipCiConfigurationLabel: s__('SecurityOrchestration|Prevent users from skipping pipelines'),
    skipCiHeader: s__(
      'SecurityOrchestration|Configure policies to control whether individual users or service accounts can use %{linkStart}skip_ci%{linkEnd} to skip pipelines.',
    ),
    skipCiExceptionText: s__('SecurityOrchestration|except for:'),
  },
  name: 'SkipCiSelector',
  components: {
    GlToggle,
    GlSprintf,
    GlLink,
    UserSelect,
  },
  props: {
    skipCiConfiguration: {
      type: Object,
      required: false,
      default: () => ({}),
    },
  },
  computed: {
    enabled() {
      return Boolean(this.skipCiConfiguration?.allowed);
    },
    selectedUsers() {
      const { allowlist: { users = [] } = {} } = this.skipCiConfiguration || {};
      return users.map(({ id }) => this.mapUserId(id)) || [];
    },
  },
  methods: {
    updateConfiguration(value) {
      this.$emit('changed', 'skip_ci', {
        allowed: !value,
      });
    },
    updateUsers(users) {
      this.$emit('changed', 'skip_ci', {
        ...this.skipCiConfiguration,
        allowed: false,
        allowlist: { users: users?.map(({ id }) => ({ id: this.mapUserId(id) })) },
      });
    },
    mapUserId(id) {
      return isNumeric(id) ? id : getIdFromGraphQLId(id);
    },
  },
};
</script>

<template>
  <div>
    <p class="gl-mb-3">
      <gl-sprintf :message="$options.i18n.skipCiHeader">
        <template #link="{ content }">
          <gl-link :href="$options.SKIP_CI_PATH" target="_blank" rel="noopener noreferrer">
            {{ content }}
          </gl-link>
        </template>
      </gl-sprintf>
    </p>
    <div class="gl-flex gl-items-center">
      <gl-toggle
        :value="!enabled"
        :label="$options.i18n.skipCiConfigurationLabel"
        label-position="left"
        data-testid="allow-selector"
        @change="updateConfiguration"
      />

      <div class="gl-align-items-center gl-ml-3 gl-flex gl-items-center">
        <span :class="{ 'gl-text-secondary': enabled }">{{
          $options.i18n.skipCiExceptionText
        }}</span>
        <user-select
          reset-on-empty
          :disabled="enabled"
          :existing-approvers="selectedUsers"
          class="gl-ml-3"
          @updateSelectedApprovers="updateUsers"
        />
      </div>
    </div>
  </div>
</template>
