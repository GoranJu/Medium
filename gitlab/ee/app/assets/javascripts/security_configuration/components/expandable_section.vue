<script>
import { GlButton, GlCollapse, GlCollapseToggleDirective } from '@gitlab/ui';
import { uniqueId } from 'lodash';
import { __ } from '~/locale';

export default {
  components: {
    GlButton,
    GlCollapse,
  },
  directives: {
    CollapseToggle: GlCollapseToggleDirective,
  },
  props: {
    headingTag: {
      type: String,
      required: false,
      default: 'h3',
    },
  },
  data() {
    return {
      collapseId: uniqueId('expandable-section-'),
      visible: false,
    };
  },
  computed: {
    toggleText() {
      return this.visible ? __('Collapse') : __('Expand');
    },
  },
};
</script>

<template>
  <section
    class="gl-border-b-1 gl-border-t-1 gl-border-default gl-py-6 gl-border-b-solid gl-border-t-solid"
  >
    <header class="gl-flex">
      <div class="gl-grow">
        <component :is="headingTag" class="gl-mt-0 gl-text-size-h2" data-testid="heading">
          <slot name="heading"></slot>
        </component>
        <p class="gl-mb-0" data-testid="sub-heading">
          <slot name="sub-heading"></slot>
        </p>
      </div>

      <gl-button v-collapse-toggle="collapseId" class="gl-ml-3 gl-shrink-0 gl-self-start">{{
        toggleText
      }}</gl-button>
    </header>

    <gl-collapse :id="collapseId" v-model="visible" data-testid="content">
      <div class="gl-mt-6"><slot></slot></div>
    </gl-collapse>
  </section>
</template>
