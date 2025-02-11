import { shallowMount } from '@vue/test-utils';
import { GlAlert } from '@gitlab/ui';
import ComplianceStandardsAdherenceReport from 'ee/compliance_dashboard/components/standards_adherence_report/report.vue';
import ComplianceStandardsAdherenceTable from 'ee/compliance_dashboard/components/standards_adherence_report/standards_adherence_table.vue';
import { mockTracking } from 'helpers/tracking_helper';

describe('ComplianceStandardsAdherenceReport component', () => {
  let wrapper;
  let trackingSpy;

  const groupPath = 'example-group';
  const projectPath = 'example-project';

  const findErrorMessage = () => wrapper.findComponent(GlAlert);
  const findAdherencesTable = () => wrapper.findComponent(ComplianceStandardsAdherenceTable);

  const createComponent = (customProvide = {}) => {
    wrapper = shallowMount(ComplianceStandardsAdherenceReport, {
      propsData: {
        groupPath,
        projectPath,
      },
      provide: { activeComplianceFrameworks: false, ...customProvide },
    });
  };

  describe('default behavior', () => {
    beforeEach(() => {
      createComponent();
    });

    it('does not render an error message', () => {
      expect(findErrorMessage().exists()).toBe(false);
    });

    it('renders the standards adherence table component', () => {
      expect(findAdherencesTable().exists()).toBe(true);
    });

    it('passes props to the standards adherence table component', () => {
      expect(findAdherencesTable().props()).toMatchObject({ groupPath, projectPath });
    });
  });

  describe('tracking', () => {
    describe('no active frameworks', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
        createComponent();
      });

      it('tracks without property', () => {
        expect(trackingSpy).toHaveBeenCalledTimes(1);
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'visit_standards_adherence', {
          property: '',
        });
      });
    });

    describe('with active frameworks', () => {
      beforeEach(() => {
        trackingSpy = mockTracking(undefined, undefined, jest.spyOn);
        createComponent({ activeComplianceFrameworks: true });
      });

      it('tracks when mounted', () => {
        expect(trackingSpy).toHaveBeenCalledTimes(1);
        expect(trackingSpy).toHaveBeenCalledWith(undefined, 'visit_standards_adherence', {
          property: 'with_active_compliance_frameworks',
        });
      });
    });
  });
});
