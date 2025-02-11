import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import DisabledSection from 'ee/security_orchestration/components/policy_editor/disabled_section.vue';

describe('DisabledSection', () => {
  let wrapper;

  const createComponent = (props = {}) => {
    wrapper = shallowMount(DisabledSection, {
      propsData: {
        disabled: false,
        ...props,
      },
      slots: {
        title: '<h2>Title</h2>',
        default: '<main>Content</main>',
      },
    });
  };

  it('renders the title slot', () => {
    createComponent();
    expect(wrapper.find('h2').text()).toBe('Title');
  });

  it('renders the default slot', () => {
    createComponent();
    expect(wrapper.find('main').text()).toBe('Content');
  });

  it('does not render the alert when not disabled', () => {
    createComponent({ disabled: false, error: 'error' });
    expect(wrapper.findComponent(GlAlert).exists()).toBe(false);
  });

  it('renders the alert when disabled and has error', () => {
    const error = 'error message';
    createComponent({ disabled: true, error });
    const alert = wrapper.findComponent(GlAlert);
    expect(alert.exists()).toBe(true);
    expect(alert.props()).toMatchObject({
      title: 'Invalid syntax',
      variant: 'warning',
      dismissible: false,
    });
    expect(alert.text()).toBe(error);
  });

  it('renders the overlay when disabled', () => {
    createComponent({ disabled: true });
    const overlay = wrapper.find('[data-testid="overlay"]');
    expect(overlay.exists()).toBe(true);
  });

  it('does not render the overlay when not disabled', () => {
    createComponent({ disabled: false });
    const overlay = wrapper.find('[data-testid="overlay"]');
    expect(overlay.exists()).toBe(false);
  });
});
