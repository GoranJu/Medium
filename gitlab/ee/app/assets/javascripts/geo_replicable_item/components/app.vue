<script>
export default {
  name: 'GeoReplicableItemApp',
  props: {
    graphqlFieldName: {
      type: String,
      required: true,
    },
    replicableItemId: {
      type: String,
      required: true,
    },
  },
};
</script>

<template>
  <div>{{ graphqlFieldName }} - {{ replicableItemId }}</div>
</template>
