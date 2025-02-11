import { GlModal } from '@gitlab/ui';
import { shallowMount } from '@vue/test-utils';
import { refreshCurrentPage } from '~/lib/utils/url_utility';
import SamlReloadModal from 'ee/saml_sso/components/saml_reload_modal.vue';
import { INTERVAL_SAML_MODAL } from 'ee/saml_sso/constants';
import { getExpiringSamlSession } from 'ee/saml_sso/saml_sessions';
import waitForPromises from 'helpers/wait_for_promises';

jest.useFakeTimers();

jest.mock('ee/saml_sso/saml_sessions', () => ({
  getExpiringSamlSession: jest.fn(),
}));

jest.mock('~/lib/utils/url_utility', () => ({
  refreshCurrentPage: jest.fn(),
}));

describe('SamlReloadModal', () => {
  let wrapper;

  const samlSessionsUrl = '/test.json';

  const createComponent = () => {
    wrapper = shallowMount(SamlReloadModal, {
      propsData: { samlProviderId: 1, samlSessionsUrl },
    });
  };

  const findModal = () => wrapper.findComponent(GlModal);

  describe('when there is no expiring SAML session', () => {
    it('does not show the modal', () => {
      createComponent();

      expect(findModal().props()).toMatchObject({
        visible: false,
        title: 'Your SAML session has expired',
        actionPrimary: {
          text: 'Reload page',
        },
        actionCancel: {
          text: 'Cancel',
        },
      });
      expect(findModal().attributes()).toMatchObject({
        'aria-live': 'assertive',
      });
    });
  });

  describe('when there is a expiring SAML sessions', () => {
    beforeEach(() => {
      const now = Date.now();
      jest
        .spyOn(Date, 'now')
        .mockReturnValueOnce(now)
        .mockReturnValueOnce(now + INTERVAL_SAML_MODAL);
    });

    it('shows the modal triggered by time elapsed', async () => {
      jest.spyOn(global, 'setInterval');
      jest.spyOn(global, 'clearInterval');
      getExpiringSamlSession.mockResolvedValue({ timeRemainingMs: INTERVAL_SAML_MODAL });
      createComponent();

      await waitForPromises();
      expect(setInterval).toHaveBeenCalledTimes(1);
      expect(setInterval).toHaveBeenCalledWith(expect.any(Function), INTERVAL_SAML_MODAL);

      jest.advanceTimersByTime(INTERVAL_SAML_MODAL);
      await waitForPromises();

      expect(findModal().props('visible')).toBe(true);
      expect(clearInterval).toHaveBeenCalledTimes(1);
      expect(clearInterval).toHaveBeenCalledWith(expect.any(Number));
    });

    it('shows the modal triggered by changevisibility event', async () => {
      jest.spyOn(document, 'addEventListener');
      jest.spyOn(document, 'removeEventListener');
      getExpiringSamlSession.mockResolvedValue({ timeRemainingMs: INTERVAL_SAML_MODAL });
      createComponent();

      await waitForPromises();
      expect(document.addEventListener).toHaveBeenCalledTimes(1);
      expect(document.addEventListener).toHaveBeenCalledWith(
        'visibilitychange',
        expect.any(Function),
      );

      document.dispatchEvent(new Event('visibilitychange'));
      await waitForPromises();

      expect(findModal().props('visible')).toBe(true);
      expect(document.removeEventListener).toHaveBeenCalledTimes(1);
      expect(document.removeEventListener).toHaveBeenCalledWith(
        'visibilitychange',
        expect.any(Function),
      );
    });

    it('triggers a refresh of the current page', () => {
      createComponent();

      findModal().vm.$emit('primary');
      expect(refreshCurrentPage).toHaveBeenCalled();
    });
  });
});
