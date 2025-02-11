import { shallowMount } from '@vue/test-utils';
import GeoReplicableItemApp from 'ee/geo_replicable_item/components/app.vue';

describe('GeoReplicableItemApp', () => {
  let wrapper;

  const propsData = {
    graphqlFieldName: 'testGraphqlFieldName',
    replicableItemId: '1',
  };

  const createComponent = () => {
    wrapper = shallowMount(GeoReplicableItemApp, {
      propsData,
    });
  };

  describe('default', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders expected result', () => {
      expect(wrapper.text()).toContain('testGraphqlFieldName - 1');
    });
  });
});
