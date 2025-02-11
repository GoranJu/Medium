<script>
export default {
  props: {
    serviceAccountId: {
      type: Number,
      required: true,
    },
  },
};
</script>

<template>
  <div>
    <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
    <p>This is the access tokens root component placeholder</p>
    <!-- eslint-disable-next-line @gitlab/vue-require-i18n-strings -->
    <p>The service account id is: {{ serviceAccountId }}</p>
  </div>
</template>
