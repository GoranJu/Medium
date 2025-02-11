<script>
import {
  GlAvatarLabeled,
  GlAvatarLink,
  GlBadge,
  GlButton,
  GlModal,
  GlModalDirective,
  GlIcon,
  GlPagination,
  GlTable,
  GlTooltip,
  GlTooltipDirective,
} from '@gitlab/ui';
// eslint-disable-next-line no-restricted-imports
import { mapActions, mapState, mapGetters } from 'vuex';
import dateFormat from '~/lib/dateformat';
import {
  FIELDS,
  AVATAR_SIZE,
  SORT_OPTIONS,
  REMOVE_BILLABLE_MEMBER_MODAL_ID,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE,
  CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX,
  DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX,
  emailNotVisibleTooltipText,
  filterUsersPlaceholder,
} from 'ee/usage_quotas/seats/constants';
import { s__, __ } from '~/locale';
import SearchAndSortBar from '~/usage_quotas/components/search_and_sort_bar/search_and_sort_bar.vue';
import glFeatureFlagMixin from '~/vue_shared/mixins/gl_feature_flags_mixin';
import RemoveBillableMemberModal from './remove_billable_member_modal.vue';
import SubscriptionSeatDetails from './subscription_seat_details.vue';

export const FIVE_MINUTES_IN_MS = 1000 * 60 * 5;

const now = () => new Date().getTime();

export default {
  name: 'SubscriptionUserList',
  directives: {
    GlModal: GlModalDirective,
    GlTooltip: GlTooltipDirective,
  },
  components: {
    GlAvatarLabeled,
    GlAvatarLink,
    GlBadge,
    GlButton,
    GlModal,
    GlIcon,
    GlPagination,
    GlTable,
    GlTooltip,
    RemoveBillableMemberModal,
    SearchAndSortBar,
    SubscriptionSeatDetails,
  },
  mixins: [glFeatureFlagMixin()],
  inject: ['subscriptionHistoryHref', 'seatUsageExportPath'],
  props: {
    hasFreePlan: {
      type: Boolean,
      required: false,
      default: true,
    },
  },
  data() {
    return {
      recentlyDeletedMembersIds: [],
    };
  },
  computed: {
    ...mapState([
      'hasError',
      'page',
      'perPage',
      'total',
      'namespaceId',
      'billableMemberToRemove',
      'search',
      'removedBillableMemberId',
    ]),
    ...mapGetters(['tableItems', 'isLoading']),
    currentPage: {
      get() {
        return this.page;
      },
      set(val) {
        this.setCurrentPage(val);
      },
    },
    emptyText() {
      if (this.search?.length < 3) {
        return s__('Billing|Enter at least three characters to search.');
      }
      return s__('Billing|No users to display.');
    },
    isLoaderShown() {
      return this.isLoading || this.hasError;
    },
    deletedMembersKey() {
      return `${this.namespaceId}-${DELETED_BILLABLE_MEMBERS_STORAGE_KEY_SUFFIX}`;
    },
    deletedMembersExpireKey() {
      return `${this.namespaceId}-${DELETED_BILLABLE_MEMBERS_EXPIRES_STORAGE_KEY_SUFFIX}`;
    },
    shouldShowDownloadSeatUsageHistory() {
      return !this.hasFreePlan;
    },
  },
  watch: {
    removedBillableMemberId(value) {
      if (!this.glFeatures.billableMemberAsyncDeletion) return;
      const uniqueMembersIds = Array.from(new Set([...this.recentlyDeletedMembersIds, value]));
      try {
        const deleteMembersString = JSON.stringify(uniqueMembersIds);
        localStorage.setItem(this.deletedMembersExpireKey, now() + FIVE_MINUTES_IN_MS);
        localStorage.setItem(this.deletedMembersKey, deleteMembersString);
      } finally {
        this.recentlyDeletedMembersIds = uniqueMembersIds;
      }
    },
  },
  mounted() {
    this.recentlyDeletedMembersIds = this.getRecentlyDeletedMembersIds();
  },
  methods: {
    ...mapActions([
      'setBillableMemberToRemove',
      'setCurrentPage',
      'setSearchQuery',
      'setSortOption',
    ]),
    formatLastLoginAt(lastLogin) {
      return lastLogin ? dateFormat(lastLogin, 'yyyy-mm-dd HH:MM:ss') : __('Never');
    },
    applyFilter(searchTerm) {
      this.setSearchQuery(searchTerm);
    },
    displayRemoveMemberModal(user) {
      if (user.removable) {
        this.setBillableMemberToRemove(user);
      } else {
        this.$refs.cannotRemoveModal.show();
      }
    },
    hasLocalStorageExpired() {
      const expire = localStorage.getItem(this.deletedMembersExpireKey);
      if (!expire) return true;
      return now() > expire;
    },
    isGroupInvite(user) {
      return user.membership_type === 'group_invite';
    },
    isProjectInvite(user) {
      return user.membership_type === 'project_invite';
    },
    isUserRemoved(user) {
      if (!this.glFeatures.billableMemberAsyncDeletion) return false;
      if (this.removedBillableMemberId === user?.id) return true;
      return this.recentlyDeletedMembersIds.includes(user?.id);
    },
    getRecentlyDeletedMembersIds() {
      try {
        if (this.hasLocalStorageExpired()) {
          localStorage.removeItem(this.deletedMembersKey);
          return [];
        }
        return JSON.parse(localStorage.getItem(this.deletedMembersKey) || '[]');
      } catch {
        return [];
      }
    },
  },
  i18n: {
    emailNotVisibleTooltipText,
    filterUsersPlaceholder,
  },
  avatarSize: AVATAR_SIZE,
  removeBillableMemberModalId: REMOVE_BILLABLE_MEMBER_MODAL_ID,
  cannotRemoveModalId: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_ID,
  cannotRemoveModalTitle: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_TITLE,
  cannotRemoveModalText: CANNOT_REMOVE_BILLABLE_MEMBER_MODAL_CONTENT,
  sortOptions: SORT_OPTIONS,
  tableFields: FIELDS,
};
</script>

<template>
  <section>
    <div class="gl-flex gl-bg-subtle gl-p-5">
      <search-and-sort-bar
        :namespace="String(namespaceId)"
        :search-input-placeholder="$options.i18n.filterUsersPlaceholder"
        :sort-options="$options.sortOptions"
        initial-sort-by="last_activity_on_desc"
        @onFilter="applyFilter"
        @onSort="setSortOption"
      />
      <gl-button
        v-if="seatUsageExportPath"
        data-testid="export-button"
        :href="seatUsageExportPath"
        class="gl-ml-3"
      >
        {{ s__('Billing|Export list') }}
      </gl-button>
      <gl-button
        v-if="shouldShowDownloadSeatUsageHistory"
        :href="subscriptionHistoryHref"
        class="gl-ml-3"
        data-testid="subscription-seat-usage-history"
      >
        {{ __('Export seat usage history') }}
      </gl-button>
    </div>

    <gl-table
      :items="tableItems"
      :fields="$options.tableFields"
      :busy="isLoaderShown"
      :show-empty="true"
      data-testid="subscription-users"
      :empty-text="emptyText"
    >
      <template #cell(disclosure)="{ item, toggleDetails, detailsShowing }">
        <gl-button
          variant="link"
          class="gl-h-7 gl-w-7"
          :aria-label="s__('Billing|Toggle seat details')"
          :aria-expanded="detailsShowing ? 'true' : 'false'"
          :data-testid="`toggle-seat-usage-details-${item.user.id}`"
          @click="toggleDetails"
        >
          <gl-icon :name="detailsShowing ? 'chevron-down' : 'chevron-right'" />
        </gl-button>
      </template>

      <template #cell(user)="{ item }">
        <div class="gl-flex">
          <gl-avatar-link target="blank" :href="item.user.web_url" :alt="item.user.name">
            <gl-avatar-labeled
              :src="item.user.avatar_url"
              :size="$options.avatarSize"
              :label="item.user.name"
              :sub-label="item.user.username"
            >
              <template #meta>
                <gl-badge v-if="isGroupInvite(item.user)" variant="muted">
                  {{ s__('Billing|Group invite') }}
                </gl-badge>
                <gl-badge v-if="isProjectInvite(item.user)" variant="muted">
                  {{ s__('Billing|Project invite') }}
                </gl-badge>
              </template>
            </gl-avatar-labeled>
          </gl-avatar-link>
        </div>
      </template>

      <template #cell(email)="{ item }">
        <div data-testid="email">
          <span v-if="item.email" class="gl-text-default">{{ item.email }}</span>
          <span
            v-else
            v-gl-tooltip
            :title="$options.i18n.emailNotVisibleTooltipText"
            class="gl-italic"
          >
            {{ s__('Billing|Private') }}
          </span>
        </div>
      </template>

      <template #cell(lastActivityTime)="data">
        <span data-testid="last_activity_on">
          {{ data.item.user.last_activity_on ? data.item.user.last_activity_on : __('Never') }}
        </span>
      </template>

      <template #cell(lastLoginAt)="data">
        <span data-testid="last_login_at">
          {{ formatLastLoginAt(data.item.user.last_login_at) }}
        </span>
      </template>

      <template #cell(actions)="data">
        <span :id="`remove-member-${data.item.user.id}`" class="gl-inline-block" tabindex="0">
          <gl-button
            v-gl-modal="$options.removeBillableMemberModalId"
            category="secondary"
            variant="danger"
            data-testid="remove-user"
            :disabled="isUserRemoved(data.item.user)"
            @click="displayRemoveMemberModal(data.item.user)"
          >
            {{ __('Remove user') }}
          </gl-button>
          <gl-tooltip
            v-if="isUserRemoved(data.item.user)"
            :target="`remove-member-${data.item.user.id}`"
          >
            {{ s__('Billing|This user is scheduled for removal.') }}</gl-tooltip
          >
        </span>
      </template>

      <template #row-details="{ item }">
        <subscription-seat-details :seat-member-id="item.user.id" />
      </template>
    </gl-table>

    <gl-pagination
      v-if="currentPage"
      v-model="currentPage"
      :per-page="perPage"
      :total-items="total"
      align="center"
      class="gl-mt-5"
    />

    <remove-billable-member-modal v-if="billableMemberToRemove" />

    <gl-modal
      ref="cannotRemoveModal"
      :modal-id="$options.cannotRemoveModalId"
      :title="$options.cannotRemoveModalTitle"
      :action-primary="/* eslint-disable @gitlab/vue-no-new-non-primitive-in-template */ {
        text: __('Okay'),
      } /* eslint-enable @gitlab/vue-no-new-non-primitive-in-template */"
      static
    >
      <p>
        {{ $options.cannotRemoveModalText }}
      </p>
    </gl-modal>
  </section>
</template>
<style>
.b-table-has-details > td:first-child {
  border-bottom: none;
}
.b-table-details > td {
  padding-top: 0 !important;
  padding-bottom: 0 !important;
}
</style>
