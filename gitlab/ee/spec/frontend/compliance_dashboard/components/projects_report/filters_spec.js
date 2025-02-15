import { mount } from '@vue/test-utils';
import { GlPopover, GlFilteredSearch, GlButton } from '@gitlab/ui';
import ComplianceFrameworksFilters from 'ee/compliance_dashboard/components/projects_report/filters.vue';

describe('ComplianceFrameworksFilters', () => {
  let wrapper;

  const findFilteredSearch = () => wrapper.findComponent(GlFilteredSearch);
  const findPopover = () => wrapper.findComponent(GlPopover);

  const createComponent = (props) => {
    wrapper = mount(ComplianceFrameworksFilters, {
      propsData: {
        value: [],
        groupPath: 'my-group-path',
        ...props,
      },
      stubs: {
        GlFilteredSearch: true,
      },
    });
  };

  describe('when showUpdatePopover is false', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders a Filtered Search component with correct props', () => {
      expect(findFilteredSearch().exists()).toBe(true);
      expect(
        findFilteredSearch()
          .props('availableTokens')
          .find((token) => token.entityType === 'framework').groupPath,
      ).toBe('my-group-path');
    });

    it('emits a "submit" event with the filters when Filtered Search component is submitted', () => {
      findFilteredSearch().vm.$emit('submit', { framework: 'my-framework' });

      expect(wrapper.emitted('submit')).toEqual([[{ framework: 'my-framework' }]]);
    });

    it('does not show update popover by default', () => {
      expect(findPopover().props('show')).toBe(false);
    });
  });

  describe('when showUpdatePopover is true', () => {
    const currentValue = [];

    beforeEach(() => {
      createComponent({ showUpdatePopover: true, value: currentValue });
    });
    it('shows update popover when showUpdatePopover is true', () => {
      expect(findPopover().props('show')).toBe(true);
    });

    it('emits submit on primary popover action', () => {
      const primaryButton = wrapper
        .findComponent(GlPopover)
        .findAllComponents(GlButton)
        .wrappers.find((w) => w.props('category') === 'primary');

      primaryButton.vm.$emit('click');
      expect(wrapper.emitted('submit').at(-1)).toStrictEqual([currentValue]);
    });
  });
});
