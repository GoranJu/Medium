<script>
import Tracking from '~/tracking';
import ComplianceStandardsAdherenceTable from './standards_adherence_table.vue';

export default {
  name: 'ComplianceStandardsAdherenceReport',
  components: {
    ComplianceStandardsAdherenceTable,
  },
  mixins: [Tracking.mixin()],
  inject: ['activeComplianceFrameworks'],
  props: {
    groupPath: {
      type: String,
      required: false,
      default: null,
    },
    projectPath: {
      type: String,
      required: false,
      default: null,
    },
  },
  mounted() {
    this.track('visit_standards_adherence', {
      property: this.activeComplianceFrameworks ? 'with_active_compliance_frameworks' : '',
    });
  },
};
</script>

<template>
  <compliance-standards-adherence-table :group-path="groupPath" :project-path="projectPath" />
</template>
