<script>
import { GlBadge, GlButton, GlCollapsibleListbox, GlExperimentBadge, GlIcon } from '@gitlab/ui';
import { s__ } from '~/locale';
import { RELEASE_STATES } from '../../self_hosted_models/constants';

export default {
  name: 'ModelSelectDropdown',
  components: {
    GlBadge,
    GlButton,
    GlCollapsibleListbox,
    GlExperimentBadge,
    GlIcon,
  },
  props: {
    selectedOption: {
      type: Object,
      required: false,
      default: null,
    },
    items: {
      type: Array,
      required: true,
    },
    dropdownToggleText: {
      type: String,
      required: true,
    },
    isFeatureSettingDropdown: {
      type: Boolean,
      required: false,
      default: false,
    },
    isLoading: {
      type: Boolean,
      required: false,
      default: false,
    },
  },
  data() {
    return {
      option: JSON.stringify(this.selectedOption) || null,
    };
  },
  computed: {
    headerText() {
      return this.isFeatureSettingDropdown ? s__('AdminAIPoweredFeatures|Compatible models') : null;
    },
  },
  methods: {
    isBetaModel(model) {
      return model?.releaseState === RELEASE_STATES.BETA;
    },
    onSelect() {
      this.$emit('select', this.option);
    },
  },
};
</script>
<template>
  <gl-collapsible-listbox
    v-model="option"
    data-testid="model-dropdown-selector"
    :items="items"
    :header-text="headerText"
    :loading="isLoading"
    category="primary"
    block
    @select="onSelect"
  >
    <template #toggle>
      <gl-button :text="dropdownToggleText" :aria-label="dropdownToggleText" block>
        <template #emoji>
          <div data-testid="dropdown-toggle-text" class="gl-flex gl-w-full gl-justify-between">
            <div class="gl-align-items gl-flex gl-overflow-hidden">
              <gl-experiment-badge
                v-if="isBetaModel(selectedOption)"
                data-testid="toggle-beta-badge"
                class="!gl-ml-0 gl-mr-3"
                type="beta"
              />
              <span class="gl-overflow-hidden gl-text-ellipsis">{{ dropdownToggleText }}</span>
            </div>
            <div>
              <gl-icon name="chevron-down" />
            </div>
          </div>
        </template>
      </gl-button>
    </template>

    <template #list-item="{ item }">
      <div v-if="isBetaModel(item)" class="gl-flex gl-items-center gl-justify-between">
        {{ item.text }}
        <gl-badge variant="neutral">{{ __('Beta') }} </gl-badge>
      </div>
    </template>

    <template v-if="isFeatureSettingDropdown" #footer>
      <div class="gl-border-t-1 gl-border-t-dropdown !gl-p-2 gl-border-t-solid">
        <gl-button data-testid="add-self-hosted-model-button" category="tertiary" to="new">
          {{ s__('AdminAIPoweredFeatures|Add self-hosted model') }}
        </gl-button>
      </div>
    </template>
  </gl-collapsible-listbox>
</template>
