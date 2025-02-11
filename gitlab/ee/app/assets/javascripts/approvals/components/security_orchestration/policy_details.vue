<script>
import { GlLink } from '@gitlab/ui';
import { s__ } from '~/locale';
import {
  humanizeRules,
  mapApproversToArray,
} from 'ee/security_orchestration/components/policy_drawer/scan_result/utils';
import { policyHasNamespace } from 'ee/security_orchestration/components/utils';
import PolicyApprovals from 'ee/security_orchestration/components/policy_drawer/scan_result/policy_approvals.vue';
import { REQUIRE_APPROVAL_TYPE } from 'ee/security_orchestration/components/policy_editor/scan_result/lib';

export default {
  i18n: {
    policyDetails: s__('SecurityOrchestration|Edit policy'),
  },
  components: {
    GlLink,
    PolicyApprovals,
  },
  props: {
    policy: {
      type: Object,
      required: true,
    },
  },
  computed: {
    humanizedRules() {
      return humanizeRules(this.policy.rules);
    },
    showEditLink() {
      return this.policy?.source?.inherited ? policyHasNamespace(this.policy.source) : true;
    },
    actionApprovers() {
      return this.policy?.actionApprovers || [];
    },
    actions() {
      return this.policy?.actions || [];
    },
    requireApprovals() {
      return this.actions?.filter((action) => action.type === REQUIRE_APPROVAL_TYPE) || [];
    },
  },
  methods: {
    mapApproversToArray(index) {
      return mapApproversToArray(this.actionApprovers[index]);
    },
    isLastIndex(index) {
      return index === this.requireApprovals.length - 1;
    },
  },
};
</script>

<template>
  <tr v-if="policy.isSelected">
    <td colspan="4" class="!gl-border-t-0 !gl-pt-0">
      <div
        class="gl-rounded-base gl-border-1 gl-border-solid gl-border-default gl-bg-white gl-px-5 gl-py-4"
      >
        <policy-approvals
          v-for="(action, index) in requireApprovals"
          :key="action.id"
          :action="action"
          :approvers="mapApproversToArray(index)"
          :is-last-item="isLastIndex(index)"
        />
        <div
          v-for="{ summary, criteriaList } in humanizedRules"
          :key="summary"
          class="gl-mb-1 gl-mt-5"
        >
          {{ summary }}
          <ul class="gl-m-0">
            <li v-for="criteria in criteriaList" :key="criteria">
              {{ criteria }}
            </li>
          </ul>
        </div>
        <div v-if="showEditLink" class="gl-text-right">
          <gl-link :href="policy.editPath" target="_blank">
            {{ $options.i18n.policyDetails }}
          </gl-link>
        </div>
      </div>
    </td>
  </tr>
</template>
