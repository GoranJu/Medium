import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import waitForPromises from 'helpers/wait_for_promises';
import GroupsListItem from '~/vue_shared/components/groups_list/groups_list_item.vue';
import GroupListItemInactiveBadge from 'ee_component/vue_shared/components/groups_list/group_list_item_inactive_badge.vue';
import { groups } from 'jest/vue_shared/components/groups_list/mock_data';

describe('GroupsListItemEE', () => {
  let wrapper;

  const [group] = groups;

  const defaultProps = { group };

  const createComponent = ({ props = {} } = {}) => {
    wrapper = shallowMountExtended(GroupsListItem, {
      propsData: { ...defaultProps, ...props },
    });
  };

  const findInactiveBadge = () => wrapper.findComponent(GroupListItemInactiveBadge);

  describe('GroupListItemInactiveBadgeEE', () => {
    it('does not render inactive badge when import is not resolved', () => {
      createComponent();

      expect(findInactiveBadge().exists()).toBe(false);
    });

    it('renders inactive badge once import is resolved', async () => {
      createComponent();
      await waitForPromises();

      expect(findInactiveBadge().exists()).toBe(true);
    });
  });
});
