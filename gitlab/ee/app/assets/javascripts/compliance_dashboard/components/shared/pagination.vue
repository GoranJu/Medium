<!-- eslint-disable vue/multi-word-component-names -->
<script>
import { GlKeysetPagination } from '@gitlab/ui';
import PageSizeSelector from '~/vue_shared/components/page_size_selector.vue';
import { setUrlParams } from '~/lib/utils/url_utility';

export default {
  components: {
    GlKeysetPagination,
    PageSizeSelector,
  },
  props: {
    pageInfo: {
      type: Object,
      required: true,
    },
    isLoading: {
      type: Boolean,
      required: true,
    },
    perPage: {
      type: Number,
      required: true,
    },
  },
  data() {
    return {
      pageSizes: [20, 50, 100],
    };
  },
  computed: {
    previousLink() {
      return setUrlParams({ before: this.pageInfo.startCursor, after: null }, window.location.href);
    },
    nextLink() {
      return setUrlParams({ before: null, after: this.pageInfo.endCursor }, window.location.href);
    },
  },
  methods: {
    loadPrevPage(previousCursor) {
      this.$emit('prev', previousCursor);
    },
    loadNextPage(nextCursor) {
      this.$emit('next', nextCursor);
    },
    onPageSizeChange(size) {
      this.$emit('page-size-change', size);
    },
    onPaginationClick(event) {
      // this check here is to ensure the proper default behaviour when a user ctrl/cmd + clicks the link
      if (event.shiftKey || event.ctrlKey || event.altKey || event.metaKey) {
        return;
      }
      event.preventDefault();
    },
  },
};
</script>

<template>
  <div v-if="pageInfo" class="gl-justify-between md:gl-flex">
    <div class="gl-hidden gl-grow gl-basis-0 md:gl-flex"></div>
    <div class="gl-float-leftmd:gl-flex gl-grow gl-basis-0 gl-justify-center">
      <gl-keyset-pagination
        v-bind="pageInfo"
        :disabled="isLoading"
        :prev-button-link="previousLink"
        :next-button-link="nextLink"
        @prev="loadPrevPage"
        @next="loadNextPage"
        @click="onPaginationClick"
      />
    </div>
    <div class="gl-float-right gl-grow gl-basis-0 gl-justify-end md:gl-flex">
      <page-size-selector :value="perPage" @input="onPageSizeChange" />
    </div>
  </div>
</template>
