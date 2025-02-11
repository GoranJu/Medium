<script>
import { GlAvatarLabeled, GlAvatarLink, GlBadge } from '@gitlab/ui';
import { s__, __ } from '~/locale';
import { fetchPolicies } from '~/lib/graphql';
import * as Sentry from '~/sentry/sentry_browser_wrapper';
import { DEFAULT_PER_PAGE } from '~/api';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import getAddOnEligibleUsers from 'ee/usage_quotas/add_on/graphql/saas_add_on_eligible_users.query.graphql';
import {
  ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE,
  ADD_ON_ERROR_DICTIONARY,
} from 'ee/usage_quotas/error_constants';
import {
  OPERATORS_IS,
  TOKEN_TITLE_ASSIGNED_SEAT,
  TOKEN_TYPE_ASSIGNED_SEAT,
} from '~/vue_shared/components/filtered_search_bar/constants';
import ErrorAlert from 'ee/vue_shared/components/error_alert/error_alert.vue';
import AddOnEligibleUserList from 'ee/usage_quotas/code_suggestions/components/add_on_eligible_user_list.vue';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  ADD_ON_CODE_SUGGESTIONS,
  ADD_ON_DUO_ENTERPRISE,
  SORT_OPTIONS,
  DEFAULT_SORT_OPTION,
} from 'ee/usage_quotas/code_suggestions/constants';
import SearchAndSortBar from 'ee/usage_quotas/code_suggestions/components/search_and_sort_bar.vue';
import BaseToken from '~/vue_shared/components/filtered_search_bar/tokens/base_token.vue';

export default {
  name: 'SaasAddOnEligibleUserList',
  avatarSize: 32,
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    AddOnEligibleUserList,
    ErrorAlert,
    SearchAndSortBar,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['fullPath'],
  props: {
    addOnPurchaseId: {
      type: String,
      required: true,
    },
    duoTier: {
      type: String,
      required: false,
      default: DUO_PRO,
      validator: (val) => [DUO_PRO, DUO_ENTERPRISE].includes(val),
    },
  },
  addOnErrorDictionary: ADD_ON_ERROR_DICTIONARY,
  data() {
    return {
      addOnEligibleUsers: undefined,
      addOnEligibleUsersFetchError: undefined,
      pageInfo: undefined,
      pageSize: DEFAULT_PER_PAGE,
      pagination: {
        first: DEFAULT_PER_PAGE,
        last: null,
        after: null,
        before: null,
      },
      filterOptions: {},
      sort: DEFAULT_SORT_OPTION,
    };
  },
  apollo: {
    addOnEligibleUsers: {
      query: getAddOnEligibleUsers,
      fetchPolicy: fetchPolicies.NETWORK_ONLY,
      nextFetchPolicy: fetchPolicies.CACHE_FIRST,
      variables() {
        return this.queryVariables;
      },
      update({ namespace }) {
        this.pageInfo = namespace?.addOnEligibleUsers?.pageInfo;
        return namespace?.addOnEligibleUsers?.nodes;
      },
      error(error) {
        this.handleAddOnUsersFetchError(error);
      },
    },
  },
  computed: {
    filterTokens() {
      if (!this.isFilteringEnabled) return [];
      return [
        {
          options: [
            { value: 'true', title: __('Yes') },
            { value: 'false', title: __('No') },
          ],
          icon: 'user',
          operators: OPERATORS_IS,
          title: TOKEN_TITLE_ASSIGNED_SEAT,
          token: BaseToken,
          type: TOKEN_TYPE_ASSIGNED_SEAT,
          unique: true,
        },
      ];
    },
    isFilteringEnabled() {
      return this.glFeatures.enableAddOnUsersFiltering;
    },
    sortOptions() {
      if (!this.isFilteringEnabled) return [];
      return SORT_OPTIONS;
    },
    queryVariables() {
      return {
        fullPath: this.fullPath,
        addOnType:
          this.duoTier === DUO_ENTERPRISE ? ADD_ON_DUO_ENTERPRISE : ADD_ON_CODE_SUGGESTIONS,
        addOnPurchaseIds: [this.addOnPurchaseId],
        sort: this.sort,
        ...this.filterOptions,
        ...this.pagination,
      };
    },
  },
  methods: {
    clearAddOnEligibleUsersFetchError() {
      this.addOnEligibleUsersFetchError = undefined;
    },
    handleAddOnUsersFetchError(error) {
      this.addOnEligibleUsersFetchError = ADD_ON_ELIGIBLE_USERS_FETCH_ERROR_CODE;
      Sentry.captureException(error);
    },
    handleNext(endCursor) {
      this.pagination = {
        first: this.pageSize,
        last: null,
        before: null,
        after: endCursor,
      };
    },
    handlePrev(startCursor) {
      this.pagination = {
        first: null,
        last: this.pageSize,
        before: startCursor,
        after: null,
      };
    },
    handleFilter(filterOptions) {
      this.pagination = {
        first: this.pageSize,
        last: null,
        after: null,
        before: null,
      };
      this.filterOptions = filterOptions;
    },
    handleSort(sort) {
      this.sort = sort;
    },
    handlePageSizeChange(size) {
      this.pageSize = size;
      this.pagination.first = size;
    },
    isGroupInvite(user) {
      return user.membershipType === 'group_invite';
    },
    isProjectInvite(user) {
      return user.membershipType === 'project_invite';
    },
    userMembershipType(user) {
      if (this.isProjectInvite(user)) {
        return s__('Billing|Project invite');
      }
      return this.isGroupInvite(user) ? s__('Billing|Group invite') : null;
    },
  },
};
</script>

<template>
  <add-on-eligible-user-list
    :add-on-purchase-id="addOnPurchaseId"
    :users="addOnEligibleUsers"
    :is-loading="$apollo.loading"
    :page-info="pageInfo"
    :page-size="pageSize"
    :search="filterOptions.search"
    :duo-tier="duoTier"
    @next="handleNext"
    @prev="handlePrev"
    @page-size-change="handlePageSizeChange"
  >
    <template #search-and-sort-bar>
      <search-and-sort-bar
        :sort-options="sortOptions"
        :tokens="filterTokens"
        @onFilter="handleFilter"
        @onSort="handleSort"
      />
    </template>
    <template #error-alert>
      <error-alert
        v-if="addOnEligibleUsersFetchError"
        data-testid="add-on-eligible-users-fetch-error"
        :error="addOnEligibleUsersFetchError"
        :error-dictionary="$options.addOnErrorDictionary"
        :dismissible="true"
        @dismiss="clearAddOnEligibleUsersFetchError"
      />
    </template>
    <template #user-cell="{ item }">
      <div class="gl-flex">
        <gl-avatar-link target="_blank" :href="item.webUrl" :alt="item.name">
          <gl-avatar-labeled
            :src="item.avatarUrl"
            :size="$options.avatarSize"
            :label="item.name"
            :sub-label="item.usernameWithHandle"
          >
            <template #meta>
              <gl-badge v-if="userMembershipType(item)" variant="muted">
                {{ userMembershipType(item) }}
              </gl-badge>
            </template>
          </gl-avatar-labeled>
        </gl-avatar-link>
      </div>
    </template>
  </add-on-eligible-user-list>
</template>
