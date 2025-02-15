<script>
import { GlCollapsibleListbox } from '@gitlab/ui';
import Pagination from '~/vue_shared/components/pagination_links.vue';
import MergeRequestTableRow from './mr_table_row.vue';

export default {
  components: {
    GlCollapsibleListbox,
    MergeRequestTableRow,
    Pagination,
  },
  props: {
    mergeRequests: {
      type: Array,
      required: true,
    },
    pageInfo: {
      type: Object,
      required: true,
    },
    columnOptions: {
      type: Array,
      required: true,
    },
    metricType: {
      type: String,
      required: true,
    },
    metricLabel: {
      type: String,
      required: true,
    },
  },
  computed: {
    metricDropdownLabel() {
      return this.columnOptions.find((option) => option.key === this.metricType).label;
    },
    showPagination() {
      return this.pageInfo && this.pageInfo.total;
    },
    listBoxColumnOptions() {
      return this.columnOptions.map(({ key, label }) => ({
        value: key,
        text: label,
      }));
    },
  },
  methods: {
    onPageChange(page) {
      this.$emit('pageChange', page);
    },
  },
};
</script>

<template>
  <div class="mr-table">
    <div class="card">
      <div class="card-header border-bottom-0 gl-bg-transparent gl-font-bold">
        <div
          role="row"
          class="gl-responsive-table-row table-row-header gl-border-b gl-flex gl-border-1 gl-border-none gl-py-0 gl-border-b-solid md:gl-border-b-0"
        >
          <div
            role="rowheader"
            class="table-section section-50 gl-hidden gl-border-none gl-px-0 md:gl-flex"
          >
            {{ __('Title') }}
          </div>
          <div role="rowheader" class="table-section section-50 !gl-border-none gl-px-0">
            <div class="gl-flex">
              <span class="gl-hidden gl-max-w-1/2 gl-shrink-0 gl-grow-0 gl-basis-1/2 md:gl-flex">{{
                __('Time to merge')
              }}</span>

              <gl-collapsible-listbox
                block
                fluid-width
                class="gl-max-w-1/2 gl-shrink-0 gl-grow-0 gl-basis-1/2"
                toggle-class="dropdown-menu-toggle !gl-w-full"
                placement="bottom-end"
                is-check-centered
                :items="listBoxColumnOptions"
                :selected="metricType"
                :toggle-text="metricDropdownLabel"
                @select="$emit('columnMetricChange', $event)"
              />
            </div>
          </div>
        </div>
      </div>
      <div class="card-body py-0">
        <merge-request-table-row
          v-for="model in mergeRequests"
          :key="model.id"
          :merge-request="model"
          :metric-type="metricType"
          :metric-label="metricLabel"
        />
      </div>
    </div>

    <pagination
      v-if="showPagination"
      :change="onPageChange"
      :page-info="pageInfo"
      class="justify-content-center gl-mt-3"
    />
  </div>
</template>
