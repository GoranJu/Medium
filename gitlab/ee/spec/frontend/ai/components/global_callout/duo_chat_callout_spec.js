import { shallowMount } from '@vue/test-utils';
import { GlPopover, GlButton, GlSprintf, GlLink } from '@gitlab/ui';
import { createMockDirective } from 'helpers/vue_mock_directive';
import { makeMockUserCalloutDismisser } from 'helpers/mock_user_callout_dismisser';
import { setHTMLFixture, resetHTMLFixture } from 'helpers/fixtures';
import UserCalloutDismisser from '~/vue_shared/components/user_callout_dismisser.vue';
import DuoChatCallout, {
  DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS,
} from 'ee/ai/components/global_callout/duo_chat_callout.vue';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

describe('DuoChatCallout', () => {
  let wrapper;
  let userCalloutDismissSpy;

  const findCalloutDismisser = () => wrapper.findComponent(UserCalloutDismisser);
  const findPopoverWithinDismisser = () => findCalloutDismisser().findComponent(GlPopover);
  const findLinkWithinDismisser = () => findCalloutDismisser().findComponent(GlButton);
  const findLearnHowLink = () => wrapper.findComponent(GlLink);
  const findTargetElements = () =>
    document.querySelectorAll(`.${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}`);
  const findFirstTargetElement = () => findTargetElements()[0];
  const findParagraphWithinPopover = () =>
    wrapper.find('[data-testid="duo-chat-callout-description"]');

  const { bindInternalEventDocument } = useMockInternalEventsTracking();

  const createComponent = ({ shouldShowCallout = true } = {}) => {
    userCalloutDismissSpy = jest.fn();
    wrapper = shallowMount(DuoChatCallout, {
      directives: {
        Outside: createMockDirective('outside'),
      },
      stubs: {
        UserCalloutDismisser: makeMockUserCalloutDismisser({
          dismiss: userCalloutDismissSpy,
          shouldShowCallout,
        }),
        GlSprintf,
      },
    });
  };

  beforeEach(() => {
    setHTMLFixture(`<button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}"></button>`);
    createComponent();
  });

  afterEach(() => {
    resetHTMLFixture();
  });

  it('renders the UserCalloutDismisser component', () => {
    expect(findCalloutDismisser().exists()).toBe(true);
    expect(findCalloutDismisser().props('featureName')).toBe('duo_chat_callout');
  });

  it('renders core elements as part of the dismisser', () => {
    expect(findPopoverWithinDismisser().exists()).toBe(true);
    expect(findLinkWithinDismisser().exists()).toBe(true);
  });

  it('renders the correct texts and link', () => {
    expect(findPopoverWithinDismisser().text()).toContain('AI features are now available');
    expect(findPopoverWithinDismisser().text()).toContain(
      'You can also use Chat in GitLab. Ask questions about:',
    );
    expect(findLearnHowLink().attributes('href')).toBe('/help/user/gitlab_duo/_index');
    expect(findLearnHowLink().text()).toBe('Learn how');
    expect(findLinkWithinDismisser().text()).toBe('Ask GitLab Duo');
  });

  it('does not render the core elements if the callout is dismissed', () => {
    createComponent({ shouldShowCallout: false });
    expect(findPopoverWithinDismisser().exists()).toBe(false);
    expect(findLinkWithinDismisser().exists()).toBe(false);
  });

  it('does not throw if the popoverTarget button does not exist', () => {
    setHTMLFixture(`<button></button>`);
    expect(() => createComponent()).not.toThrow();
    expect(findFirstTargetElement()).toBeUndefined();
    expect(wrapper.text()).toBe('');
  });

  describe('popover target', () => {
    it('passes the correct target to the popover when there is only one potential target element', () => {
      const el = findFirstTargetElement();
      expect(findPopoverWithinDismisser().props('target')).toEqual(el);
    });
    it('passes the correct target to the popover when there are several potentiaL target elements', () => {
      setHTMLFixture(`
        <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}" style="display: none"></button>
        <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}" style="visibility: hidden"></button>
        <button class="${DUO_CHAT_GLOBAL_BUTTON_CSS_CLASS}"></button>
      `);
      const expectedElement = findTargetElements()[2];
      createComponent();
      expect(findPopoverWithinDismisser().props('target')).toEqual(expectedElement);
    });
  });

  describe('interaction', () => {
    it("dismisses the callout when the popover's close button is clicked, but doesn't open the chat", () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      findPopoverWithinDismisser().vm.$emit('close-button-clicked');

      expect(userCalloutDismissSpy).toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
    });

    it("doesn't dismiss the callout and doesn't open the chat when user clicks within the callout", async () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      await findParagraphWithinPopover().trigger('click');

      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
    });

    it('dismisses the callout and opens the chat when the chat button is clicked', () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
      findFirstTargetElement().click();
      expect(userCalloutDismissSpy).toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeDefined();
    });

    it('dismisses the callout and opens the chat when the popover button is clicked', () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();
      findLinkWithinDismisser().vm.$emit('click');
      expect(userCalloutDismissSpy).toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeDefined();
    });

    it('does not try to dismiss the callout if the button is clicked after the callout is already dismissed', () => {
      expect(userCalloutDismissSpy).not.toHaveBeenCalled();
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      findPopoverWithinDismisser().vm.$emit('close-button-clicked');
      expect(userCalloutDismissSpy).toHaveBeenCalledTimes(1);
      expect(wrapper.emitted('callout-dismissed')).toBeUndefined();

      findFirstTargetElement().click();
      expect(userCalloutDismissSpy).toHaveBeenCalledTimes(1);
    });

    it('does not fail if the chat button is clicked after callout was dismissed', () => {
      createComponent({ shouldShowCallout: false });
      expect(() => findFirstTargetElement().click()).not.toThrow();
    });
  });

  describe('tracking', () => {
    it('should track render', () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      expect(trackEventSpy).toHaveBeenCalledWith('render_duo_chat_callout', {}, undefined);
    });

    it('should track click learn how link', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findLearnHowLink().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_learn_how_link_duo_chat_callout',
        {},
        undefined,
      );
    });

    it('should track dismiss', async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findLinkWithinDismisser().vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith('dismiss_duo_chat_callout', {}, undefined);
    });
  });
});
