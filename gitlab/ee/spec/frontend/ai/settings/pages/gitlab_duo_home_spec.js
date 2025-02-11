import { shallowMount } from '@vue/test-utils';
import { stubComponent } from 'helpers/stub_component';
import CodeSuggestionsUsage from 'ee/usage_quotas/code_suggestions/components/code_suggestions_usage.vue';
import HealthCheckList from 'ee/usage_quotas/code_suggestions/components/health_check_list.vue';
import DuoSeatUtilizationInfoCard from 'ee/ai/settings/components/duo_seat_utilization_info_card.vue';
import GitlabDuoHome from 'ee/ai/settings/pages/gitlab_duo_home.vue';

describe('GitLab Duo Home', () => {
  const mockSlotProps = {
    totalValue: 100,
    usageValue: 50,
    duoTier: 'pro',
  };

  let wrapper;

  const createComponent = ({ isSaaS = true } = {}) => {
    wrapper = shallowMount(GitlabDuoHome, {
      propsData: {},
      provide: {
        isSaaS,
      },
      stubs: {
        CodeSuggestionsUsage: stubComponent(CodeSuggestionsUsage, {
          template: `
            <div>
              <slot name="health-check"></slot>
              <slot name="duo-card" v-bind="$options.mockSlotProps"></slot>
            </div>
          `,
          mockSlotProps,
        }),
      },
    });
  };

  const findCodeSuggestionsUsage = () => wrapper.findComponent(CodeSuggestionsUsage);
  const findHealthCheckList = () => wrapper.findComponent(HealthCheckList);
  const findDuoSeatUtilizationInfoCard = () => wrapper.findComponent(DuoSeatUtilizationInfoCard);

  describe('component rendering', () => {
    beforeEach(() => {
      createComponent();
    });

    it('renders the components', () => {
      expect(findCodeSuggestionsUsage().exists()).toBe(true);
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
    });

    it(`passes the correct props to CodeSuggestionsUsage`, () => {
      expect(findCodeSuggestionsUsage().props()).toMatchObject({
        title: 'GitLab Duo',
        subtitle:
          'Monitor, manage, and customize AI features to ensure efficient utilization and alignment.',
        forceHideTitle: false,
      });
    });

    describe('when isSaaS is true', () => {
      it('renders HealthCheckList', () => {
        expect(findHealthCheckList().exists()).toBe(false);
      });
    });

    describe('when isSaaS is false', () => {
      beforeEach(() => {
        createComponent({ isSaaS: false });
      });

      it('renders HealthCheckList', () => {
        expect(findHealthCheckList().exists()).toBe(true);
      });
    });

    it('renders DuoSeatUtilizationInfoCard with correct props', () => {
      expect(findDuoSeatUtilizationInfoCard().exists()).toBe(true);
      expect(findDuoSeatUtilizationInfoCard().props()).toMatchObject(mockSlotProps);
    });
  });
});
