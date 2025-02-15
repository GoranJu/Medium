import { shallowMount } from '@vue/test-utils';
import { GlCard, GlButton } from '@gitlab/ui';
import UsageStatistics from 'ee/usage_quotas/components/usage_statistics.vue';
import DuoSeatUtilizationInfoCard from 'ee/ai/settings/components/duo_seat_utilization_info_card.vue';
import {
  DUO_PRO,
  DUO_ENTERPRISE,
  CODE_SUGGESTIONS_TITLE,
  DUO_ENTERPRISE_TITLE,
} from 'ee/usage_quotas/code_suggestions/constants';
import { useMockInternalEventsTracking } from 'helpers/tracking_internal_events_helper';

jest.mock('~/lib/utils/url_utility');

describe('DuoSeatUtilizationInfoCard', () => {
  let wrapper;

  const createComponent = (props = {}, injected = {}) => {
    return shallowMount(DuoSeatUtilizationInfoCard, {
      propsData: {
        usageValue: 5,
        totalValue: 10,
        ...props,
      },
      provide: {
        addDuoProHref: 'http://example.com/add-duo-pro',
        duoAddOnStartDate: '2023-01-01',
        duoAddOnEndDate: '2023-12-31',
        duoSeatUtilizationPath: 'http://example.com/duo-seat-utilization',
        ...injected,
      },
    });
  };

  const { bindInternalEventDocument } = useMockInternalEventsTracking();
  const findCard = () => wrapper.findComponent(GlCard);
  const findUsageStats = () => wrapper.findComponent(UsageStatistics);
  const findActionButtons = () => wrapper.findAllComponents(GlButton);
  const findSeatUtilizationTitle = () => wrapper.find('[data-testid="duo-seat-utilization-info"]');
  const findSeatUtilizationDescription = () =>
    wrapper.find('[data-testid="duo-seat-utilization-description"]');
  const findSubscriptionDates = () =>
    wrapper.find('[data-testid="duo-seat-utilization-subscription-dates"]');

  beforeEach(() => {
    wrapper = createComponent();
  });

  describe('when action button clicked', () => {
    it('Assign seats button has the correct URL', () => {
      expect(findActionButtons().at(0).attributes('href')).toBe(
        'http://example.com/duo-seat-utilization',
      );
    });

    it('Purchase seats button has the correct URL', () => {
      expect(findActionButtons().at(1).attributes('href')).toBe('http://example.com/add-duo-pro');
    });

    it(`tracks the "click_purchase_seats_button_group_duo_pro_home_page" event`, async () => {
      const { trackEventSpy } = bindInternalEventDocument(wrapper.element);

      await findActionButtons().at(1).vm.$emit('click');

      expect(trackEventSpy).toHaveBeenCalledWith(
        'click_purchase_seats_button_group_duo_pro_home_page',
        {
          label: `duo_pro_purchase_seats`,
        },
        'groups:gitlab_duo:show',
      );
    });
  });

  describe('general rendering', () => {
    it('renders GlCard when total value and percentage are available', () => {
      expect(findCard().exists()).toBe(true);
    });

    it('renders UsageStatistics with correct props', () => {
      expect(findUsageStats().props()).toMatchObject({
        percentage: 50,
        totalValue: '10',
        usageValue: '5',
      });
    });

    it('renders correct title in description slot', () => {
      expect(findSeatUtilizationTitle().text()).toBe('Seat utilization');
    });

    it('renders correct description in additional-info slot', () => {
      expect(findSeatUtilizationDescription().text()).toContain('A user can be assigned a');
    });

    it('sets duoTitle correctly based on duoTier', () => {
      wrapper = createComponent({ duoTier: DUO_PRO });
      expect(findSeatUtilizationDescription().text()).toContain(CODE_SUGGESTIONS_TITLE);

      wrapper = createComponent({ duoTier: DUO_ENTERPRISE });
      expect(findSeatUtilizationDescription().text()).toContain(DUO_ENTERPRISE_TITLE);
    });

    it('renders subscription dates correctly', () => {
      expect(findSubscriptionDates().text()).toContain('Start date: Jan 01, 2023');
      expect(findSubscriptionDates().text()).toContain('End date: Dec 31, 2023');
    });

    it('renders action buttons correctly', () => {
      expect(findActionButtons()).toHaveLength(2);
      expect(findActionButtons().at(0).text()).toBe('Assign seats');
      expect(findActionButtons().at(1).text()).toBe('Purchase seats');
    });

    it('renders only assign seats button for duo enterprise', () => {
      wrapper = createComponent({ duoTier: DUO_ENTERPRISE });

      expect(findActionButtons()).toHaveLength(1);
      expect(findActionButtons().at(0).text()).toBe('Assign seats');
    });
  });
});
