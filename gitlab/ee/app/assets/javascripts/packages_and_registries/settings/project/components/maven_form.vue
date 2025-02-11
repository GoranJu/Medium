<script>
import { GlFormGroup, GlFormInput } from '@gitlab/ui';

export default {
  name: 'MavenForm',
  components: {
    GlFormGroup,
    GlFormInput,
  },
  props: {
    value: {
      type: Object,
      required: true,
    },
  },
  methods: {
    onModelChange(newValue, model) {
      this.$emit('input', { ...this.value, [model]: newValue });
    },
  },
};
</script>

<template>
  <div>
    <h5 class="gl-mt-6">{{ s__('PackageRegistry|Maven') }}</h5>
    <gl-form-group
      :label="__('URL')"
      :description="s__('DependencyProxy|Base URL of the external registry.')"
      label-for="maven-url"
    >
      <gl-form-input
        id="maven-url"
        :value="value.mavenExternalRegistryUrl"
        width="xl"
        @input="onModelChange($event.trim(), 'mavenExternalRegistryUrl')"
      />
    </gl-form-group>
    <gl-form-group
      :label="__('Username')"
      :description="s__('DependencyProxy|Username of the external registry.')"
      label-for="maven-username"
    >
      <gl-form-input
        id="maven-username"
        :value="value.mavenExternalRegistryUsername"
        width="xl"
        @input="onModelChange($event.trim(), 'mavenExternalRegistryUsername')"
      />
    </gl-form-group>
    <gl-form-group
      :label="__('Password')"
      :description="s__('DependencyProxy|Password for your external registry.')"
      label-for="maven-password"
    >
      <gl-form-input
        id="maven-password"
        :value="value.mavenExternalRegistryPassword"
        width="xl"
        type="password"
        @input="onModelChange($event, 'mavenExternalRegistryPassword')"
      />
    </gl-form-group>
  </div>
</template>
