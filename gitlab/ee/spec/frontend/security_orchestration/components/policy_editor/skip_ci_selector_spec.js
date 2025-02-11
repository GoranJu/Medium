import { GlToggle } from '@gitlab/ui';
import SkipCiSelector from 'ee/security_orchestration/components/policy_editor/skip_ci_selector.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';
import UserSelect from 'ee/security_orchestration/components/policy_editor/scan_result/action/user_select.vue';

describe('SkipCiSelector', () => {
  let wrapper;

  const createComponent = (propsData = {}) => {
    wrapper = shallowMountExtended(SkipCiSelector, {
      propsData,
    });
  };

  const findAllowSkipCiSelector = () => wrapper.findComponent(GlToggle);
  const findUserSelect = () => wrapper.findComponent(UserSelect);

  it('renders allow skip ci option by default', () => {
    createComponent();
    expect(findUserSelect().exists('resetOnEmpty')).toBe(true);
    expect(findUserSelect().exists()).toBe(true);
    expect(findAllowSkipCiSelector().exists()).toBe(true);

    expect(findAllowSkipCiSelector().props('value')).toBe(true);
    expect(findUserSelect().props('disabled')).toBe(false);
  });

  it('enabled skip ci skip option', () => {
    createComponent();

    findAllowSkipCiSelector().vm.$emit('change', true);

    expect(wrapper.emitted('changed')).toEqual([['skip_ci', { allowed: false }]]);
  });

  it('selects user exceptions', () => {
    createComponent({
      skipCiConfiguration: { allowed: false },
    });

    findUserSelect().vm.$emit('updateSelectedApprovers', [{ id: 1 }]);

    expect(wrapper.emitted('changed')).toEqual([
      ['skip_ci', { allowed: false, allowlist: { users: [{ id: 1 }] } }],
    ]);
  });

  it.each`
    users                                                             | expected
    ${[{ id: 1 }, { id: 2 }]}                                         | ${[1, 2]}
    ${[{ id: 'gid://gitlab/User/1' }, { id: 'gid://gitlab/User/2' }]} | ${[1, 2]}
  `('renders user exceptions dropdown', ({ users, expected }) => {
    createComponent({
      skipCiConfiguration: { allowed: false, allowlist: { users } },
    });

    expect(findUserSelect().props('existingApprovers')).toEqual(expected);
  });

  it('selects user exceptions in graphql format', () => {
    createComponent({
      skipCiConfiguration: { allowed: false },
    });

    findUserSelect().vm.$emit('updateSelectedApprovers', [
      { id: 'gid://gitlab/User/1' },
      { id: 'gid://gitlab/User/2' },
    ]);

    expect(wrapper.emitted('changed')).toEqual([
      ['skip_ci', { allowed: false, allowlist: { users: [{ id: 1 }, { id: 2 }] } }],
    ]);
  });

  it('renders user exceptions dropdown when skip ci is true', () => {
    createComponent({
      skipCiConfiguration: { allowed: true },
    });

    expect(findUserSelect().exists()).toBe(true);
    expect(findUserSelect().props('disabled')).toBe(true);
  });
});
