import { GlIcon, GlSprintf, GlTooltip } from '@gitlab/ui';
import {
  SEVERITY_CLASS_NAME_MAP,
  SEVERITY_TOOLTIP_TITLE_MAP,
} from 'ee/vue_shared/security_reports/components/constants';
import SeverityBadge from 'ee/vue_shared/security_reports/components/severity_badge.vue';
import { createMockDirective, getBinding } from 'helpers/vue_mock_directive';
import TimeAgoTooltip from '~/vue_shared/components/time_ago_tooltip.vue';
import { shallowMountExtended } from 'helpers/vue_test_utils_helper';

describe('Severity Badge', () => {
  const SEVERITY_LEVELS = ['critical', 'high', 'medium', 'low', 'info', 'unknown'];
  const MOCK_LAST_SEVERITY_OVERRIDE = {
    changed_by: 'Security Research User',
    new_severity: 'high',
    original_severity: 'medium',
    changed_at: new Date().toISOString(),
  };

  let wrapper;

  const createWrapper = (propsData = {}, stubs = {}) => {
    wrapper = shallowMountExtended(SeverityBadge, {
      propsData: { ...propsData },
      directives: {
        GlTooltip: createMockDirective('gl-tooltip'),
      },
      stubs: {
        ...stubs,
      },
    });
  };

  const findIcon = () => wrapper.findComponent(GlIcon);
  const findTooltip = () => getBinding(findIcon().element, 'gl-tooltip').value;
  const findSeverityOverridesTooltip = () => wrapper.findComponent(GlTooltip);
  const findTimeAgoTooltip = () => wrapper.findComponent(TimeAgoTooltip);
  const findGlSprintf = () => wrapper.findComponent(GlSprintf);
  const findSeverityOverridesText = () => wrapper.findByTestId('severity-override');

  describe.each(SEVERITY_LEVELS)('given a valid severity "%s"', (severity) => {
    beforeEach(() => {
      createWrapper({ severity });
    });

    const className = SEVERITY_CLASS_NAME_MAP[severity];

    it(`renders the component with ${severity} badge`, () => {
      expect(wrapper.find(`.${className}`).exists()).toBe(true);
    });

    it('renders gl-icon with correct name', () => {
      expect(findIcon().props('name')).toBe(`severity-${severity}`);
    });

    it(`renders the component label`, () => {
      const severityFirstLetterUpper = `${severity.charAt(0).toUpperCase()}${severity.slice(1)}`;
      expect(wrapper.text()).toBe(severityFirstLetterUpper);
    });

    it('renders tooltip', () => {
      expect(findTooltip()).toBe(SEVERITY_TOOLTIP_TITLE_MAP[severity]);
    });
  });

  describe.each(['foo', '', ' '])('given an invalid severity "%s"', (invalidSeverity) => {
    beforeEach(() => {
      createWrapper({ severity: invalidSeverity });
    });

    it(`renders an empty component`, () => {
      expect(wrapper.find('*').exists()).toBe(false);
    });
  });

  describe('when severityOverrides is provided', () => {
    beforeEach(() => {
      createWrapper(
        {
          severity: 'medium',
          severityOverrides: { nodes: [MOCK_LAST_SEVERITY_OVERRIDE] },
          showSeverityOverrides: true,
        },
        {
          GlSprintf,
          TimeAgoTooltip,
        },
      );
    });

    it('renders the changed severity icon and tooltip', () => {
      expect(findSeverityOverridesText().exists()).toBe(true);
      expect(findSeverityOverridesTooltip().exists()).toBe(true);
    });

    it('renders the changes severity text in the tooltip', () => {
      expect(findSeverityOverridesText().text()).toMatchInterpolatedText(
        `${MOCK_LAST_SEVERITY_OVERRIDE.changed_by} changed the severity from ${MOCK_LAST_SEVERITY_OVERRIDE.original_severity} to ${MOCK_LAST_SEVERITY_OVERRIDE.new_severity} just now.`,
      );
    });

    it('renders the time-ago-tooltip component with the correct date', () => {
      createWrapper(
        {
          severity: 'medium',
          severityOverrides: { nodes: [MOCK_LAST_SEVERITY_OVERRIDE] },
          showSeverityOverrides: true,
        },
        { GlSprintf },
      );
      expect(findTimeAgoTooltip().props('time')).toBe(MOCK_LAST_SEVERITY_OVERRIDE.changed_at);
    });
  });

  describe('when severityOverrides is provided and showSeverityOverrides is not', () => {
    beforeEach(() => {
      createWrapper({
        severity: 'medium',
        severityOverrides: { nodes: [MOCK_LAST_SEVERITY_OVERRIDE] },
        showSeverityOverrides: false,
      });
    });

    it('does not renders the changed severity icon and tooltip', () => {
      expect(findSeverityOverridesText().exists()).toBe(false);
      expect(findSeverityOverridesTooltip().exists()).toBe(false);
      expect(findGlSprintf().exists()).toBe(false);
    });
  });
});
