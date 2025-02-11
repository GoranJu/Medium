import { GlBadge } from '@gitlab/ui';
import { RouterLinkStub } from '@vue/test-utils';
import { mountExtended } from 'helpers/vue_test_utils_helper';
import NavItem from '~/super_sidebar/components/nav_item.vue';

describe('EE NavItem component', () => {
  let wrapper;

  const findPill = () => wrapper.findComponent(GlBadge);

  const createWrapper = ({ item, props = {}, provide = {}, routerLinkSlotProps = {} }) => {
    wrapper = mountExtended(NavItem, {
      propsData: {
        item,
        ...props,
      },
      provide,
      stubs: {
        RouterLink: {
          ...RouterLinkStub,
          render(h) {
            const children = this.$scopedSlots.default({
              href: '/foo',
              isActive: false,
              navigate: jest.fn(),
              ...routerLinkSlotProps,
            });
            return h('a', children);
          },
        },
      },
    });
  };

  describe('pills', () => {
    describe('if `pill_count_field` exists, use it to get async count', () => {
      it.each`
        pillCountField              | asyncCountValue | result
        ${'openIssuesCount'}        | ${0}            | ${0}
        ${'openIssuesCount'}        | ${10}           | ${10}
        ${'openIssuesCount'}        | ${100234}       | ${'100.2k'}
        ${'openMergeRequestsCount'} | ${0}            | ${0}
        ${'openMergeRequestsCount'} | ${10}           | ${10}
        ${'openMergeRequestsCount'} | ${100234}       | ${'100.2k'}
        ${'openEpicsCount'}         | ${0}            | ${0}
        ${'openEpicsCount'}         | ${10}           | ${10}
        ${'openEpicsCount'}         | ${100234}       | ${'100.2k'}
      `(
        'returns `$result` when nav item `pill_count_field` is `$pillCountField` and count is `$asyncCountValue`',
        ({ pillCountField, asyncCountValue, result }) => {
          createWrapper({
            item: {
              pill_count: 0,
              pill_count_field: pillCountField,
            },
            props: {
              asyncCount: {
                [pillCountField]: asyncCountValue,
              },
            },
          });
          expect(findPill().text()).toBe(`${result}`);
        },
      );
    });

    describe('if `pill_count_field` does not exist, use `pill_count` value`', () => {
      it('renders `pill_count_field` value based on item type', () => {
        createWrapper({ item: { title: 'Foo', pill_count: 10, pill_count_field: null } });

        expect(findPill().text()).toBe('10');
      });
    });
  });
});
